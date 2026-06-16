# frozen_string_literal: true

require "active_model"

module Plutonium
  module Wizard
    # Author-facing base class for wizards (§2). A wizard declares ordered `step`s
    # (with their own field surface, branching `condition:`, and optional per-step
    # `on_submit`/`on_rollback`), an optional terminal `review` step, and commits
    # at the end via `execute`.
    #
    # This class is pure object behaviour — declaring the DSL, exposing the
    # ordered steps, the union `data` snapshot, and the `anchor`/`fail!`
    # accessors. HTTP/runner/store wiring lives elsewhere.
    #
    # @example
    #   class CompanyOnboardingWizard < Plutonium::Wizard::Base
    #     step :company do
    #       attribute :name, :string
    #       input :name
    #       validates :name, presence: true
    #     end
    #     review label: "Review"
    #
    #     def execute
    #       succeed(Company.create!(name: data.name))
    #     end
    #   end
    class Base
      include ActiveModel::Model
      include Plutonium::Definition::Presentable
      include DSL

      attr_reader :data_attributes
      attr_accessor :view_context
      attr_writer :anchor, :scope, :token

      # Identity/concurrency context (§4.5), supplied by the runner/driving layer
      # so `concurrency_key` resolvers and the tenancy fold can reach them.
      # `wizard_token` is the per-run id (the identity for guest/repeatable runs,
      # available inside `concurrency_key`) — NOT a pre-auth principal that
      # survives login.
      attr_accessor :current_user, :current_scoped_entity, :wizard_token

      # The runner reuses a single wizard instance across a request, reassigning
      # `data_attributes` between reads, so invalidate the memoized `data` snapshot
      # whenever the staged attributes change.
      def data_attributes=(attrs)
        @data_attributes = attrs
        @data = nil
      end

      def initialize(view_context: nil, **)
        @view_context = view_context
        @data_attributes = {}
        super()
      end

      class << self
        # Per-step data spec ({step_key => {schema:, options:, structured:}}), used
        # to build the step-keyed `data` container (§2.6). Each step contributes its
        # OWN schema/options/structured — no cross-step union, so two steps may share
        # a field name without colliding. `using:` imports are already composed into
        # each step's `attribute_schema`.
        def data_steps_spec
          steps.reject(&:review?).each_with_object({}) do |step, acc|
            acc[step.key.to_sym] = {
              schema: step.attribute_schema,
              options: step.attribute_options,
              structured: step_structured_schema(step)
            }
          end
        end

        # The per-step typed sub-object classes ({step_key => Class}), built once
        # per wizard class from {data_steps_spec} and reused for every `data`
        # snapshot (the container is cheap to instantiate; the classes aren't).
        def data_step_classes
          @data_step_classes ||= data_steps_spec.transform_values do |spec|
            Data.class_for(spec[:schema], options: spec[:options], structured: spec[:structured])
          end
        end

        private

        # One step's structured collections, as {name => [sub-field names]}, so
        # `data.<step>.<name>` exposes typed sub-objects (§2.6 / §7.2).
        def step_structured_schema(step)
          step.structured_inputs.each_with_object({}) do |(name, entry), acc|
            acc[name.to_sym] = structured_sub_fields(entry)
          end
        end

        # Resolve the declared sub-field names of a structured_input entry by
        # evaluating its block (or `using:` holder) against a FieldsDefinition.
        def structured_sub_fields(entry)
          options = entry[:options] || {}
          return Array(options[:fields]).map(&:to_sym) if options[:fields]

          holder =
            if options[:using]
              options[:using].is_a?(Class) ? options[:using].new : options[:using]
            else
              h = Plutonium::Definition::StructuredInputs::FieldsDefinition.new
              entry[:block]&.call(h)
              h
            end
          holder.defined_inputs.keys.map(&:to_sym)
        end
      end

      # The step-keyed `data` snapshot (§2.6), reconstituted from the nested staged
      # `data_attributes` ({step_key => {field => value}}). Addressed as
      # `data.<step>.<field>`; `data[:step]` for dynamic access.
      def data
        @data ||= Data::Container.new(self.class.data_step_classes, data_attributes)
      end

      # The record this wizard was launched against (§3). Raises when the wizard
      # was not declared `anchored` — never returns nil.
      def anchor
        unless self.class.anchored?
          raise NotAnchoredError, "#{self.class} is not declared `anchored`"
        end
        @anchor
      end

      # Resolve this wizard's concurrency_key VALUE(S) in the wizard context
      # (§4.2), with the tenant ALWAYS folded in (§4.4). Returns nil when no
      # `concurrency_key` is declared (→ tokened identity). The returned value is
      # an array `[*key_values, tenant_gid]`; {InstanceKey.concurrency} serializes
      # it. The tenant is appended even when nil so the digest is stable.
      def concurrency_key_value
        resolver = self.class.concurrency_key_resolver
        return nil unless resolver

        key = instance_exec(&resolver)
        [*Array.wrap(key), current_scoped_entity]
      end

      # The `{ "step_key" => [gids] }` source the runner injects from the stored
      # state, backing the lazy `persisted` view. Reassigning it resets the memo.
      def persisted_gid_source=(source)
        @persisted = LazyPersisted.new(source)
      end

      # Records the per-step `on_submit`/`persist` macro registers (§2.2), as a
      # LAZY view over the stored GIDs: a key is located on first read and
      # memoized, so a request that never reads `persisted` issues zero locates
      # (§4.5). Records set this request (the `persist` macro) are live already.
      def persisted
        @persisted ||= LazyPersisted.new
      end

      # The at-end commit hook (§2.3). Authors override it.
      def execute
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      private

      # Raise a StepError from `on_submit`/`execute` (§6.1).
      #
      #   fail!("message")        → base (form-level) error
      #   fail!(:field, "message") → field-level error
      def fail!(attribute_or_message, message = nil)
        if message.nil?
          raise StepError.new(attribute_or_message, attribute: :base)
        else
          raise StepError.new(message, attribute: attribute_or_message)
        end
      end

      # @return [Plutonium::Interaction::Outcome::Success]
      def succeed(value = nil)
        Plutonium::Interaction::Outcome::Success.new(value)
      end
      alias_method :success, :succeed

      # @return [Plutonium::Interaction::Outcome::Failure]
      def failed(errors = nil, attribute = :base)
        case errors
        when Hash
          errors.each { |attr, error| self.errors.add(attr, error) }
        else
          Array(errors).each { |error| self.errors.add(attribute, error) }
        end
        Plutonium::Interaction::Outcome::Failure.new
      end
    end
  end
end

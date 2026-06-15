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
        # The union of every non-review step's inline attribute schema, used to
        # build the typed `data` snapshot (§2.6). `using:` imports merge in later.
        def union_attribute_schema
          steps.reject(&:review?).each_with_object({}) do |step, acc|
            acc.merge!(step.attribute_schema)
          end
        end

        # The union of every non-review step's per-attribute options
        # ({name => {default:, ...}}), threaded into the typed `data` snapshot.
        def union_attribute_options
          steps.reject(&:review?).each_with_object({}) do |step, acc|
            acc.merge!(step.attribute_options)
          end
        end

        # Structured collections across all steps, as {name => [sub-field names]},
        # so `data.<name>` exposes typed sub-objects (§2.6 / §7.2).
        def structured_data_schema
          steps.reject(&:review?).each_with_object({}) do |step, acc|
            step.structured_inputs.each do |name, entry|
              acc[name.to_sym] = structured_sub_fields(entry)
            end
          end
        end

        private

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

      # Typed, dot-accessible snapshot over the union schema, reconstituted from
      # the staged `data_attributes` each call site needs it (§2.6).
      def data
        @data ||= Data.class_for(
          self.class.union_attribute_schema,
          options: self.class.union_attribute_options,
          structured: self.class.structured_data_schema
        ).new(data_attributes)
      end

      # The record this wizard was launched against (§3). Raises when the wizard
      # was not declared `anchored` — never returns nil.
      def anchor
        unless self.class.anchored?
          raise NotAnchoredError, "#{self.class} is not declared `anchored`"
        end
        @anchor
      end

      # Records the per-step `on_submit`/`persist` macro registers (§2.2),
      # rehydrated by the runner. Empty here.
      def persisted
        @persisted ||= {}
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

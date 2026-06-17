# frozen_string_literal: true

module Plutonium
  module Wizard
    # Records the field surface declared inside a `step` block.
    #
    # A step block reuses Plutonium's existing field DSL — `attribute`, `input`,
    # `validates`, `structured_input`, `form_layout` — plus the per-step hooks
    # `on_submit` and `on_rollback`. This object captures all of it by
    # `instance_exec`-ing the block against itself.
    #
    # The union `data` schema (§2.6) is built from inline `attribute name, type`
    # declarations recorded here as `attribute_schema` ({name => type}).
    #
    # `using:` import (a model — see FieldImporter) is recorded as a marker
    # (`using_spec`) and merged lazily; this object only captures inline
    # declarations and composes them over the resolved import (inline wins).
    class FieldCapture
      include Plutonium::Definition::DefineableProps
      include Plutonium::Definition::StructuredInputs
      include Plutonium::Definition::FormLayout

      defineable_props :field, :input

      attr_reader :validations, :hooks, :using_spec

      def self.build(using: nil, using_opts: {}, &block)
        capture = new
        capture.record_using(using, using_opts) if using
        capture.instance_exec(&block) if block
        capture
      end

      def initialize
        @inline_attribute_schema = {}
        @inline_attribute_options = {}
        @validations = []
        @hooks = {}
      end

      # Inline `attribute :name, :type` — records the union-schema type and any
      # options (default:, etc.), which are threaded into the typed `data`
      # snapshot so e.g. `default:` applies (§2.6).
      def attribute(name, type = :string, **options)
        key = name.to_sym
        @inline_attribute_schema[key] = type
        @inline_attribute_options[key] = options unless options.empty?
        self
      end

      # The effective union-schema types for this step ({name => type}), composing
      # a `using:` import with inline `attribute` declarations — **inline wins on a
      # name conflict** (§2.4). The imported surface is resolved lazily.
      def attribute_schema
        imported_spec ? imported_spec.attribute_schema.merge(@inline_attribute_schema) : @inline_attribute_schema
      end

      # The effective per-attribute options ({name => {default:, ...}}). Imports
      # contribute none (types come from the source; options stay inline); inline
      # declarations are returned as-is.
      def attribute_options
        @inline_attribute_options
      end

      # The effective input config ({name => {options:, block:}}) — imported inputs
      # composed with inline `input`/`field` declarations, inline winning on
      # conflict. Drives the step form (Task 6).
      def inputs
        imported = imported_spec ? imported_spec.inputs : {}
        imported.merge(defined_inputs)
      end

      # The form_layout for this step (§7.1 resolution order): an inline
      # `form_layout` wins; else the layout inherited from a `using:` source
      # (already filtered to the imported fields); else nil (default single grid).
      def form_layout_sections
        @form_layout || imported_spec&.form_layout
      end

      # The imported validation runner ({attribute => [messages]} over a data
      # slice), or nil when there's no `using:` import or `validate: false`. The
      # runner (Task 4) combines this with inline `validates`.
      def imported_validate_fn
        imported_spec&.validate_fn
      end

      # The imported model's form-relevant validators ([[name], options] pairs),
      # replayed onto the typed data class so imported fields render their
      # required/length/etc. metadata. Empty without a `using:` import. Distinct
      # from `validations` (inline, runner-bound) so imports aren't double-validated.
      def imported_form_validators
        imported_spec&.form_validators || []
      end

      # The resolved `using:` import surface, or nil. Memoized.
      def imported_spec
        return @imported_spec if defined?(@imported_spec)
        @imported_spec =
          if @using_spec
            FieldImporter.resolve(using: @using_spec[:using], opts: @using_spec[:opts])
          end
      end

      # Inline `validates` — recorded as raw args for the runner (Task 4) to apply.
      def validates(*args, **options)
        @validations << [args, options]
        self
      end

      # Instance-level structured_input: the step block runs at instance level,
      # but the StructuredInputs concern only exposes a class method. Record into
      # a per-instance registry mirroring `defined_structured_inputs`.
      def structured_input(name, **options, &block)
        unless block || options[:using] || options[:fields]
          raise ArgumentError,
            "`structured_input :#{name}` needs a block, `using:`, or `fields:`"
        end
        instance_structured_inputs[name] = {options:, block:}.compact
      end

      def defined_structured_inputs
        instance_structured_inputs
      end

      def on_submit(&block)
        @hooks[:on_submit] = block
      end

      def on_rollback(&block)
        @hooks[:on_rollback] = block
      end

      # form_layout is provided by the FormLayout concern as a class method; the
      # step block runs at instance level, so expose an instance-level shim that
      # records onto this capture's own builder.
      def form_layout(&block)
        raise ArgumentError, "`form_layout` requires a block" unless block
        builder = Plutonium::Definition::FormLayout::Builder.new
        builder.instance_exec(&block)
        @form_layout = builder.sections.freeze
      end

      def record_using(using, opts)
        @using_spec = {using:, opts: opts || {}}
      end

      # Pop a recorded hook (used by the DSL when building the Step).
      def delete_hook(name) = @hooks.delete(name)

      private

      def instance_structured_inputs
        @instance_structured_inputs ||= {}
      end
    end
  end
end

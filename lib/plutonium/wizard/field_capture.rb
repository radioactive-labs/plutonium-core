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
    # `using:` import (Task 3) is recorded as a marker (`using_spec`) and merged
    # later; this object only captures inline declarations.
    class FieldCapture
      include Plutonium::Definition::DefineableProps
      include Plutonium::Definition::StructuredInputs
      include Plutonium::Definition::FormLayout

      defineable_props :field, :input

      attr_reader :attribute_schema, :attribute_options, :validations, :hooks, :using_spec

      def self.build(using: nil, using_opts: {}, &block)
        capture = new
        capture.record_using(using, using_opts) if using
        capture.instance_exec(&block) if block
        capture
      end

      def initialize
        @attribute_schema = {}
        @attribute_options = {}
        @validations = []
        @hooks = {}
      end

      # Inline `attribute :name, :type` — records the union-schema type and any
      # options (default:, etc.), which are threaded into the typed `data`
      # snapshot so e.g. `default:` applies (§2.6).
      def attribute(name, type = :string, **options)
        key = name.to_sym
        @attribute_schema[key] = type
        @attribute_options[key] = options unless options.empty?
        self
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
        unless block || options[:using]
          raise ArgumentError,
            "`structured_input :#{name}` needs a block or `using:`"
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

      def form_layout_sections = @form_layout

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

# frozen_string_literal: true

module Plutonium
  module Wizard
    # Metadata for one wizard step: its key, label, branching condition, captured
    # field surface, per-step hooks, and the `using:` import marker (resolved in
    # Task 3). A value object — holds no runtime state.
    class Step
      attr_reader :key, :label, :condition, :fields,
        :on_submit, :on_rollback, :using_spec, :form_layout

      def initialize(key:, fields:, label: nil, condition: nil,
        on_submit: nil, on_rollback: nil, using_spec: nil, form_layout: nil)
        @key = key
        @label = label || key.to_s.humanize
        @condition = condition
        @fields = fields
        @on_submit = on_submit
        @on_rollback = on_rollback
        @using_spec = using_spec
        @form_layout = form_layout
      end

      def review? = false

      # The inline attribute schema ({name => type}) contributed to the union
      # `data` schema. `using:` imports are merged in later (Task 3).
      def attribute_schema = fields.attribute_schema

      # The structured inputs declared in this step ({name => {options:, block:}}).
      def structured_inputs = fields.defined_structured_inputs
    end
  end
end

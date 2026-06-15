# frozen_string_literal: true

module Plutonium
  module Wizard
    # Metadata for one wizard step: its key, label, branching condition, captured
    # field surface, per-step hooks, and the `using:` import marker (resolved in
    # Task 3). A value object — holds no runtime state.
    class Step
      attr_reader :key, :label, :condition, :fields,
        :on_submit, :on_rollback, :using_spec

      def initialize(key:, fields:, label: nil, condition: nil,
        on_submit: nil, on_rollback: nil, using_spec: nil)
        @key = key
        @label = label || key.to_s.humanize
        @condition = condition
        @fields = fields
        @on_submit = on_submit
        @on_rollback = on_rollback
        @using_spec = using_spec
      end

      def review? = false

      # The step's form sections (§7.1): inline `form_layout` wins, else the layout
      # inherited from a `using:` source (filtered to imported fields), else nil.
      # Resolved lazily so a `using:` import is only loaded when actually needed.
      def form_layout = fields.form_layout_sections

      # The effective attribute schema ({name => type}) contributed to the union
      # `data` schema — a `using:` import composed with inline `attribute`
      # declarations (inline wins on conflict, §2.4).
      def attribute_schema = fields.attribute_schema

      # The per-attribute options ({name => {default:, ...}}) contributed to the
      # typed `data` snapshot, so e.g. `default:` applies (§2.6).
      def attribute_options = fields.attribute_options

      # The effective input config ({name => {options:, block:}}) — imported inputs
      # composed with inline `input`/`field` declarations (inline wins).
      def inputs = fields.inputs

      # Inline `validates` declarations recorded for this step (raw [args, options]).
      def validations = fields.validations

      # The imported validation runner ({attribute => [messages]} over a data
      # slice), or nil when there's no `using:` import or `validate: false`.
      def imported_validate_fn = fields.imported_validate_fn

      # The structured inputs declared in this step ({name => {options:, block:}}).
      def structured_inputs = fields.defined_structured_inputs
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module Wizard
    # The built-in terminal review step (§2.5). Declares no fields of its own;
    # auto-summarizes collected `data` and gates Finish → `execute`. Must be the
    # last declared step.
    class ReviewStep < Step
      # Minimal stand-in for a step's field surface — a review step has none.
      class EmptyFields
        def attribute_schema = {}

        def attribute_options = {}

        def inputs = {}

        def validations = []

        def imported_form_validators = []

        def imported_validate_fn = nil

        def form_layout_sections = nil

        def defined_structured_inputs = {}
      end

      attr_reader :block, :summary, :header

      def initialize(key: :review, label: "Review", description: nil, condition: nil, summary: true, header: true, block: nil)
        super(key:, label:, description:, condition:, fields: EmptyFields.new)
        @summary = summary
        @header = header
        @block = block
      end

      def review? = true

      # Whether the auto-summary of completed steps renders in the COMPLETE state
      # (see the `review summary:` macro). Always true in the incomplete state.
      def summary? = @summary

      # Whether the step-header section (label + prompt) renders above the review
      # body (see the `review header:` macro).
      def header? = @header
    end
  end
end

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

        def defined_structured_inputs = {}
      end

      attr_reader :block

      def initialize(key: :review, label: "Review", condition: nil, block: nil)
        super(key:, label:, condition:, fields: EmptyFields.new)
        @block = block
      end

      def review? = true
    end
  end
end

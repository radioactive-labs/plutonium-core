# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # An array value edited as chips: a multi-select (slim-select) whose
        # options are the current values plus any `suggestions:`.
        #
        #   addable: false  only suggestions can be picked (default: values
        #                   can be typed in)
        #   limit: 5        caps the number of chips
        class List < Phlexi::Form::Components::Select
          protected

          def build_attributes
            @suggestions = Array(attributes.delete(:suggestions))
            @limit = attributes.delete(:limit)
            @addable = attributes.delete(:addable) != false

            attributes[:multiple] = true
            attributes[:choices] ||= (current_values + @suggestions.map(&:to_s)).uniq
            attributes[:data_slim_select_addable_value] = "true" if @addable
            attributes[:data_slim_select_max_selected_value] = @limit if @limit
            super
          end

          def current_values = Array(field.value).map(&:to_s)

          def selected?(option) = current_values.include?(option.to_s)

          # Selecting nothing submits the hidden "" alone, which clears the list.
          def normalize_input(input_value)
            super&.reject(&:blank?)
          end

          # Typed-in values aren't among the rendered choices, so only a
          # non-addable list restricts the submission to them.
          def normalize_simple_input(input_value)
            @addable ? input_value&.to_s : super
          end
        end
      end
    end
  end
end

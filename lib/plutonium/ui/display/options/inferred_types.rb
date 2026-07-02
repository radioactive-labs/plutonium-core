# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Options
        module InferredTypes
          include Plutonium::UI::Options::HasCentsField

          private

          def infer_field_component
            # has_cents decimal accessors infer as :float/:decimal; render money.
            return :currency if has_cents_field?

            case inferred_field_type
            when :attachment
              :attachment
            when :boolean
              # phlexi-display falls back to :string, rendering "true"/"false".
              :boolean
            when :enum
              :badge
            else
              super
            end
          end
        end
      end
    end
  end
end

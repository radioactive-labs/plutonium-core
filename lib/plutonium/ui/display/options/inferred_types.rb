# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Options
        module InferredTypes
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

          def has_cents_field?
            klass = object.class
            klass.respond_to?(:has_cents_decimal_attribute?) && klass.has_cents_decimal_attribute?(key)
          end
        end
      end
    end
  end
end

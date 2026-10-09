# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # phlexi's Number coerces through Float(), which drops a decimal
        # column's scale (10.50 → "10.5") and digits past ~15 significant
        # figures. Decimals stay BigDecimal and render at the column's scale.
        # Explicit `options:` still go straight to number_to_delimited.
        class Number < Phlexi::Display::Components::Number
          private

          def format_number(value)
            return super unless value.is_a?(BigDecimal) && @options.empty?

            digits = scale ? ActiveSupport::NumberHelper.number_to_rounded(value, precision: scale) : value.to_s("F")
            ActiveSupport::NumberHelper.number_to_delimited(digits)
          end

          def normalize_value(value)
            value.is_a?(BigDecimal) ? value : super
          end

          def scale
            field.object.class.try(:type_for_attribute, field.key)&.scale
          end
        end
      end
    end
  end
end

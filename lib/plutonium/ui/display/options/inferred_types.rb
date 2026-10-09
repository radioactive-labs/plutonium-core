# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Options
        module InferredTypes
          include Plutonium::UI::Options::HasCentsField
          include Plutonium::UI::Options::SecretField

          private

          def infer_field_component
            # Mask the same secret-bearing names the form does, so the show
            # page and table never print what the form refuses to echo.
            return :password if secret_field_name?

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

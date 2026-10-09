# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Options
        module InferredTypes
          include Plutonium::UI::Options::HasCentsField
          include Plutonium::UI::Options::SecretField
          include Plutonium::UI::Options::TagsField
          include Plutonium::UI::Options::RichTextField

          private

          def infer_field_component
            return :tags if tags_field?
            return :rich_text if rich_text_field?

            # Mask the same secret-bearing names the form does, so the show
            # page and table never print what the form refuses to echo.
            return :password if secret_field_name?

            # has_cents decimal accessors infer as :float/:decimal; render money.
            return :currency if has_cents_field?

            case inferred_field_type
            when :attachment
              :attachment
            when :binary
              # phlexi-display falls back to :string, printing the raw bytes.
              :binary
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

# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Options
        module InferredTypes
          include Plutonium::UI::Options::HasCentsField

          private

          def infer_field_component
            # Password detection lives in the string-type inference, not the
            # component-type inference (a `password` column infers as :string).
            # Route every inferred password/secret field to the masking Password
            # component so the stored value never reaches the DOM. We also widen
            # the heuristic to secret-bearing names Phlexi misses (`*_secret`,
            # `*_key`, `salt`, ...) — see #secret_field_name?.
            return :password if inferred_string_field_type == :password || secret_field_name?

            # has_cents decimal accessors render as a currency input (number field
            # + unit prefix), mirroring the display — no explicit `as: :currency`.
            return :currency if has_cents_field?

            case inferred_field_type
            when :rich_text
              return :markdown
            end

            inferred_field_component = super
            case inferred_field_component
            when :select
              :slim_select
            when :date, :time, :datetime
              :flatpickr
            when :boolean
              :toggle
            else
              inferred_field_component
            end
          end

          # Secret-bearing names Phlexi's `is_password_field?` does not catch
          # (it only handles `password`, `encrypted_*`, `*_password`, `*_digest`,
          # `*_hash`, `*_token`). Mask these too so their value never reaches the
          # DOM. Still a name heuristic, not a guarantee — opt in/out per field
          # with `as: :password` / `as: :string`.
          def secret_field_name?
            name = key.to_s.downcase
            name == "token" || name == "salt" ||
              name.include?("secret") ||
              name.end_with?("_key", "_salt")
          end
        end
      end
    end
  end
end

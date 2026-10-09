# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Options
        module InferredTypes
          include Plutonium::UI::Options::HasCentsField
          include Plutonium::UI::Options::SecretField
          include Plutonium::UI::Options::TagsField

          private

          def infer_field_component
            # A tag context is also a has_many of tag records; claim it first.
            return :tags if tags_field?
            # Password detection lives in the string-type inference, not the
            # component-type inference (a `password` column infers as :string).
            # Route every inferred password/secret field to the masking Password
            # component so the stored value never reaches the DOM. We also widen
            # the heuristic to secret-bearing names Phlexi misses (`*_secret`,
            # `*_key`, `salt`, ...) — see Options::SecretField.
            return :password if inferred_string_field_type == :password || secret_field_name?

            # has_cents decimal accessors render as a currency input (number field
            # + unit prefix), mirroring the display — no explicit `as: :currency`.
            return :currency if has_cents_field?

            case inferred_field_type
            when :rich_text
              return :markdown
            when :binary
              # phlexi-form infers :file, which Plutonium renders as an Uppy
              # attachment; a binary column holds the file's bytes instead.
              return :binary
            when :json, :jsonb
              # phlexi-form infers these as a plain :text textarea, which
              # renders `Hash#to_s` and never parses the submission back.
              return :json
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
        end
      end
    end
  end
end

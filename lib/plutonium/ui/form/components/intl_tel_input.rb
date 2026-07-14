# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class IntlTelInput < Phlexi::Form::Components::Input
          def view_template
            div(data: {
              controller: "intl-tel-input",
              intl_tel_input_options_value: @intl_options.to_json
            }) {
              super
            }
          end

          private

          def build_input_attributes
            super
            attributes[:data_intl_tel_input_target] = tokens(attributes[:data_intl_tel_input_target], :input)
            @intl_options = build_intl_options
          end

          # Options forwarded to the intl-tel-input library via the Stimulus
          # controller's `options` value. Supports a convenient `initial_country:`
          # shortcut plus an `intl_options:` hash for any other library option
          # (keys are the library's own camelCase names, e.g. `separateDialCode`).
          # Both are deleted from `attributes` so they don't leak onto the <input>.
          #
          #   input :phone, as: :phone, initial_country: "gh"
          #   input :phone, as: :phone, intl_options: {separateDialCode: true, strictMode: false}
          #
          # When no country is given, falls back to
          # `Plutonium.configuration.default_phone_country`.
          def build_intl_options
            options = {}
            if (country = attributes.delete(:initial_country) || Plutonium.configuration.normalized_default_phone_country)
              options[:initialCountry] = country
            end
            if (extra = attributes.delete(:intl_options))
              options.merge!(extra)
            end
            options
          end
        end
      end
    end
  end
end

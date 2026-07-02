# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # A numeric (money) input with an OPTIONAL currency-unit prefix. The unit
        # is resolved by the SAME rules as the currency *display*
        # ({Display::Components::Currency.resolve_unit}), so the input and the
        # show/index/summary render the same symbol: an explicit `unit:` (a
        # literal "£", a Symbol read off the record, or `false` for none) → the
        # record's `has_cents` unit → `default_currency_unit` / the i18n default.
        # When nothing resolves (or `unit: false`) the prefix is omitted and it's
        # a plain number input.
        #
        #   input :price, as: :currency               # → configured/i18n default unit
        #   input :price, as: :currency, unit: "£"
        #   input :price, as: :currency, unit: false  # no prefix
        class Currency < Phlexi::Form::Components::Input
          def view_template
            return super if @unit_prefix.blank?

            # Overlay the unit at the input's left edge; the currency-input
            # Stimulus controller measures this prefix and sets the input's
            # left padding to match, so digits always clear it whatever the
            # symbol's width ("$" vs "GH₵").
            div(class: "relative", data: {controller: "currency-input"}) do
              span(
                class: "pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-sm text-[var(--pu-text-muted)]",
                aria_hidden: "true",
                data: {currency_input_target: "prefix"}
              ) { plain @unit_prefix }
              super
            end
          end

          protected

          def build_input_attributes
            @unit_prefix = resolve_unit_prefix
            attributes[:type] = :number
            attributes[:inputmode] = "decimal"
            attributes[:step] ||= "0.01"
            # Mark the input so the currency-input controller can measure the
            # prefix and set the exact left padding at connect (see the JS).
            if @unit_prefix.present?
              attributes[:data] = (attributes[:data] || {}).merge(currency_input_target: "field")
            end
            super
          end

          private

          # Resolve the prefix and strip `unit:` from the attributes so it never
          # leaks onto the <input>. Returns "" when there's no unit to show.
          def resolve_unit_prefix
            explicit = attributes.delete(:unit)
            Plutonium::UI::Display::Components::Currency.resolve_unit(explicit, field.object, field.key)
          end
        end
      end
    end
  end
end

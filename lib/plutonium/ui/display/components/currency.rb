# frozen_string_literal: true

require "active_support/number_helper"

module Plutonium
  module UI
    module Display
      module Components
        # Renders a numeric value as currency (delimited, 2 decimals). The symbol
        # is resolved by {resolve_unit}: an explicit `unit:` (a literal "£", a
        # Symbol read off the record for per-row currencies, or `false` for no
        # symbol) → the record's `has_cents` unit → `default_currency_unit` /
        # the i18n `number.currency.format.unit` ($ in en).
        #
        #   display :price, as: :currency               # → configured/i18n default unit
        #   display :price, as: :currency, unit: "£"
        #   display :price, as: :currency, unit: :currency_symbol
        #   display :price, as: :currency, unit: false  # no symbol
        class Currency < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          # Resolves the currency unit string for a value, shared by this
          # component and the grid/kanban {Grid::Card} so both format currency
          # identically. Precedence, where `nil` means "not set, keep looking"
          # and `false` means "explicitly no symbol, stop":
          #   explicit unit → record's has_cents unit → configured/i18n default.
          #
          # @param explicit [String, Symbol, false, nil] a per-display `unit:`.
          # @param record [Object] the record being rendered.
          # @param key [Symbol] the attribute name.
          # @return [String] the unit to pass to number_to_currency ("" for none).
          def self.resolve_unit(explicit, record, key)
            unit = explicit
            unit = record.has_cents_unit_for(key) if unit.nil? && record.respond_to?(:has_cents_unit_for)
            unit = default_unit if unit.nil?

            case unit
            when nil, false then ""
            when Symbol then record.public_send(unit).to_s
            else unit.to_s
            end
          end

          # The unit used when nothing more specific is configured. Returns the
          # `default_currency_unit` config verbatim when set (including `false`
          # to disable the symbol); otherwise the i18n `number.currency.format.unit`
          # *if the locale defines it*, else no symbol. We don't hardcode a "$".
          def self.default_unit
            config = Plutonium.configuration.default_currency_unit
            return config unless config.nil?

            I18n.t("number.currency.format.unit", default: "")
          end

          def render_value(value)
            p(**attributes) { format_currency(value) }
          end

          protected

          def build_attributes
            @unit = attributes.delete(:unit)
            @options = attributes.delete(:options) || {}
            super
          end

          private

          def format_currency(value)
            ActiveSupport::NumberHelper.number_to_currency(value, unit: resolved_unit, **@options)
          end

          def resolved_unit
            self.class.resolve_unit(@unit, field.object, field.key)
          end

          def normalize_value(value) = value
        end
      end
    end
  end
end

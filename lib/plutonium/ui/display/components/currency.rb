# frozen_string_literal: true

require "active_support/number_helper"

module Plutonium
  module UI
    module Display
      module Components
        # Renders a numeric value as currency (delimited, 2 decimals). No symbol
        # by default; pass a literal `unit:` ("£") or a Symbol read off the
        # record (`unit: :currency_symbol`) for per-row currencies.
        #
        #   display :price, as: :currency
        #   display :price, as: :currency, unit: "£"
        #   display :price, as: :currency, unit: :currency_symbol
        class Currency < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

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
            case @unit
            when nil then ""
            when Symbol then field.object.public_send(@unit)
            else @unit
            end
          end

          def normalize_value(value) = value
        end
      end
    end
  end
end

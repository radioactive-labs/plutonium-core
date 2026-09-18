# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # A single headline number with an optional change indicator.
      #
      # The card's block returns either the value itself or a hash:
      #
      #   {value: 1_240}                                   # just the number
      #   {value: 1_240, previous: 1_100}                  # change computed: +12.7%
      #   {value: 1_240, change: 12.7}                     # change in percentage points
      #   {value: 1_240, change: "+140", trend: :up}       # change shown verbatim
      #   {value: 98.2, change_label: "vs. last week"}     # caption after the change
      #
      # `format:` picks the number formatter (`:number`, `:currency`,
      # `:percentage`, `:human`, or a proc run on the dashboard); `positive:`
      # says which direction is good (`:up` by default, `:down` for churn or
      # error rates) and drives the change colour.
      class Metric < Card
        include ActiveSupport::NumberHelper

        private

        def render_body
          data = normalize(card.evaluate(dashboard))

          div(class: "pu-metric") do
            div(class: "pu-metric-value") { format_value(data[:value]) }
            render_change(data) if data[:change] || data[:change_label]
          end
        end

        def normalize(result)
          data = result.is_a?(Hash) ? result.symbolize_keys : {value: result}
          data[:change_label] ||= card.options[:change_label]

          if !data.key?(:change) && data[:previous].is_a?(Numeric) && data[:value].is_a?(Numeric)
            data[:change] = percent_change(data[:value], data[:previous])
          end

          data[:trend] ||= infer_trend(data[:change]) if data.key?(:change)
          data
        end

        def percent_change(value, previous)
          return nil if previous.zero?

          ((value - previous) / previous.to_f.abs) * 100
        end

        def infer_trend(change)
          case change
          when Numeric
            if change.positive? then :up
            elsif change.negative? then :down
            else :flat
            end
          when String
            if change.start_with?("-") then :down
            elsif change.start_with?("+") then :up
            else :flat
            end
          end
        end

        def render_change(data)
          trend = data[:trend] || :flat
          div(class: tokens("pu-metric-change", change_tone_class(trend))) do
            render_trend_icon(trend)
            span(class: "font-medium") { format_change(data[:change]) } if data[:change]
            span(class: "pu-metric-change-label") { data[:change_label] } if data[:change_label].present?
          end
        end

        def render_trend_icon(trend)
          icon = case trend
          when :up then Phlex::TablerIcons::TrendingUp
          when :down then Phlex::TablerIcons::TrendingDown
          else Phlex::TablerIcons::Minus
          end
          render icon.new(class: "size-4 shrink-0")
        end

        def change_tone_class(trend)
          return "pu-metric-change-neutral" if trend == :flat || trend.nil?

          good = (trend == :up) == (card.options[:positive] == :up)
          good ? "pu-metric-change-positive" : "pu-metric-change-negative"
        end

        def format_change(change)
          case change
          when Numeric
            sign = change.positive? ? "+" : ""
            "#{sign}#{number_to_rounded(change, precision: 1, strip_insignificant_zeros: true)}%"
          else change.to_s
          end
        end

        def format_value(value)
          return t("plutonium.dashboard.metric.empty") if value.nil?

          formatted = case (format = card.options[:format])
          when Proc then dashboard.instance_exec(value, &format)
          when :currency then number_to_currency(value, **currency_options)
          when :percentage then number_to_percentage(value, precision: precision(1))
          when :human then number_to_human(value, precision: precision(3))
          else format_number(value)
          end

          [card.options[:prefix], formatted, card.options[:suffix]].compact.join
        end

        def format_number(value)
          return value.to_s unless value.is_a?(Numeric)

          if card.options[:precision] || value.is_a?(Float)
            number_to_rounded(value, precision: precision(value.is_a?(Float) ? 2 : 0), delimiter: ",", strip_insignificant_zeros: true)
          else
            number_to_delimited(value)
          end
        end

        def currency_options
          options = {precision: precision(2)}
          options[:unit] = card.options[:unit] if card.options[:unit]
          options
        end

        def precision(default)
          card.options.fetch(:precision, default)
        end
      end
    end
  end
end

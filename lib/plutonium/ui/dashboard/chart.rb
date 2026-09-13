# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # A Chartkick chart. The card's block returns Chartkick data (a
      # `{label => value}` hash, an array of pairs, or an array of
      # `{name:, data:}` series); this component serialises it onto a
      # `data-controller="chart"` element and the Stimulus controller draws it
      # once the on-demand charts bundle has loaded.
      class Chart < Card
        def initialize(dashboard:, card:, script_url: nil)
          super(dashboard:, card:)
          @script_url = script_url
        end

        private

        def render_body
          data = card.evaluate(dashboard)

          div(
            class: "pu-chart",
            style: "height: #{card.options[:height]};",
            data: {
              controller: "chart",
              chart_type_value: card.chart_class,
              chart_data_value: data.to_json,
              chart_options_value: card.chart_options.to_json,
              chart_script_value: script_url
            }
          ) do
            span(class: "pu-chart-loading") { t("plutonium.ui.loading") }
          end
        end

        def script_url
          @script_url || view_context.resource_charts_script_url
        end
      end
    end
  end
end

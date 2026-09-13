# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # The placeholder a lazy card's frame shows until its response lands.
      # Shaped like the card it stands in for, so the grid does not jump when
      # the real card arrives.
      class Skeleton < Plutonium::UI::Component::Base
        def initialize(card:)
          @card = card
        end

        def view_template
          div(role: "status", class: "pu-card pu-dashboard-card pu-dashboard-skeleton h-full motion-safe:animate-pulse") do
            div(class: "h-3 w-24 rounded-full bg-[var(--pu-border-strong)]")
            render_body
            span(class: "sr-only") { t("plutonium.dashboard.loading_card", card: @card.label) }
          end
        end

        private

        def render_body
          case @card.kind
          when :metric
            div(class: "mt-4 h-8 w-32 rounded-[var(--pu-radius-md)] bg-[var(--pu-border)]")
            div(class: "mt-3 h-2 w-20 rounded-full bg-[var(--pu-border)]")
          when :chart
            div(class: "mt-4 rounded-[var(--pu-radius-md)] bg-[var(--pu-border)]", style: "height: #{@card.options[:height]};")
          else
            div(class: "mt-4 h-2 w-full rounded-full bg-[var(--pu-border)]")
            div(class: "mt-3 h-2 w-5/6 rounded-full bg-[var(--pu-border)]")
            div(class: "mt-3 h-2 w-2/3 rounded-full bg-[var(--pu-border)]")
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # The card grid. Every lazy card is a `<turbo-frame src loading="lazy">`
      # holding a skeleton of its own shape, so the page paints at once and
      # each card's queries run in a separate request as it scrolls into
      # view. A card declared `lazy: false` renders inline.
      class Board < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag

        # The grid is 12 columns on large screens, 2 on tablets and 1 on
        # phones. Written out in full so Tailwind's scanner sees every class it
        # must emit; a span is picked from this table, never interpolated.
        GRID_CLASSES = "pu-dashboard grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-12"

        SPAN_CLASSES = {
          1 => "lg:col-span-1",
          2 => "lg:col-span-2",
          3 => "lg:col-span-3",
          4 => "lg:col-span-4",
          5 => "lg:col-span-5",
          6 => "md:col-span-2 lg:col-span-6",
          7 => "md:col-span-2 lg:col-span-7",
          8 => "md:col-span-2 lg:col-span-8",
          9 => "md:col-span-2 lg:col-span-9",
          10 => "md:col-span-2 lg:col-span-10",
          11 => "md:col-span-2 lg:col-span-11",
          12 => "md:col-span-2 lg:col-span-12"
        }.freeze

        def initialize(dashboard:)
          @dashboard = dashboard
        end

        def view_template
          cards = dashboard.visible_cards
          return EmptyCard(t("plutonium.dashboard.no_cards")) if cards.empty?

          div(class: GRID_CLASSES, data: {dashboard: dashboard.class.i18n_key}) do
            cards.each { |card| render_slot(card) }
          end
        end

        private

        attr_reader :dashboard

        def render_slot(card)
          if card.lazy?
            turbo_frame_tag(
              card.frame_id,
              src: dashboard_card_path(card),
              loading: "lazy",
              refresh: "morph",
              class: tokens("block", span_classes(card)),
              **refresh_attributes(card)
            ) { render Skeleton.new(card:) }
          else
            div(class: span_classes(card)) { render Card.for(dashboard:, card:) }
          end
        end

        # On a tablet's two columns a card half the desktop row or wider takes
        # the full row; anything narrower takes one column.
        def span_classes(card) = SPAN_CLASSES.fetch(card.span)

        # `refresh` wires the `frame-refresh` controller, which reloads the
        # frame every N seconds while the tab is visible.
        def refresh_attributes(card)
          seconds = dashboard.refresh_for(card)
          return {} unless seconds

          {data: {controller: "frame-refresh", frame_refresh_interval_value: seconds}}
        end
      end
    end
  end
end

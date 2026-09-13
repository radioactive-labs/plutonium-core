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

        # Written out in full so Tailwind's scanner sees every class it must
        # emit; the grid columns and spans are picked from these tables, never
        # interpolated.
        COLUMN_CLASSES = {
          1 => "lg:grid-cols-1",
          2 => "lg:grid-cols-2",
          3 => "lg:grid-cols-3",
          4 => "lg:grid-cols-4",
          5 => "lg:grid-cols-5",
          6 => "lg:grid-cols-6"
        }.freeze

        SPAN_CLASSES = {
          2 => "md:col-span-2 lg:col-span-2",
          3 => "md:col-span-2 lg:col-span-3",
          4 => "md:col-span-2 lg:col-span-4",
          5 => "md:col-span-2 lg:col-span-5",
          6 => "md:col-span-2 lg:col-span-6",
          :full => "md:col-span-full lg:col-span-full"
        }.freeze

        def initialize(dashboard:)
          @dashboard = dashboard
        end

        def view_template
          cards = dashboard.visible_cards
          return EmptyCard(t("plutonium.dashboard.no_cards")) if cards.empty?

          div(class: grid_classes, data: {dashboard: dashboard.class.i18n_key}) do
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

        def grid_classes
          columns = dashboard.class.columns
          tokens("pu-dashboard grid grid-cols-1 gap-4", (columns > 1) ? "md:grid-cols-2" : nil, COLUMN_CLASSES.fetch(columns))
        end

        # A span wider than the grid collapses to the full row rather than
        # overflowing it.
        def span_classes(card)
          columns = dashboard.class.columns
          span = card.span
          return nil if span == 1 || columns == 1
          return SPAN_CLASSES.fetch(:full) if span == :full || span >= columns

          SPAN_CLASSES.fetch(span)
        end

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

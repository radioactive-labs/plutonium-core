# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # The card chrome every kind shares: a `pu-card` with an optional icon,
      # the title (linked when the card has an `href:`), an optional
      # description, and a body the subclass fills in.
      #
      # The body is rendered under a guard: outside local-request mode a
      # card whose block raises logs and reports the error and renders a short
      # notice in place, so one broken query never takes the whole dashboard down.
      class Card < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::LinkTo

        # The component class for a declared card.
        def self.for(dashboard:, card:)
          component = case card.kind
          when :metric then Metric
          when :chart then Chart
          else Custom
          end
          component.new(dashboard:, card:)
        end

        def initialize(dashboard:, card:)
          @dashboard = dashboard
          @card = card
        end

        def view_template
          Block(class: tokens("pu-dashboard-card flex flex-col h-full", card_classes)) do
            render_header
            div(class: "pu-dashboard-card-body") { guarded { render_body } }
          end
        end

        private

        attr_reader :dashboard, :card

        def render_body
          raise NotImplementedError, "#{self.class}#render_body"
        end

        # Extra classes a kind adds to the card surface.
        def card_classes = nil

        def render_header
          div(class: "pu-dashboard-card-header") do
            render_icon if card.icon
            div(class: "min-w-0 flex-1") do
              h3(class: "pu-dashboard-card-title") { render_title }
              if (description = card.description).present?
                p(class: "pu-dashboard-card-description") { description }
              end
            end
            render_link if href
          end
        end

        def render_icon
          div(class: "pu-dashboard-card-icon") { render card.icon.new(class: "size-5") }
        end

        def render_title
          if href
            a(href:, class: "hover:underline") { card.label }
          else
            card.label
          end
        end

        def render_link
          a(href:, class: "pu-dashboard-card-link", aria: {label: t("plutonium.dashboard.open")}) do
            render Phlex::TablerIcons::ArrowUpRight.new(class: "size-4")
          end
        end

        def href
          return @href if defined?(@href)

          @href = card.href_for(dashboard)
        end

        # Render the body into a string first, so a failure leaves no
        # half-written markup behind before the notice replaces it.
        def guarded(&)
          html = capture(&)
          raw(safe(html))
        rescue => e
          raise if raise_card_errors?

          report_error(e)
          render_error
        end

        # Logged as well as reported: `Rails.error.report` writes nothing to
        # the log, so with no error subscriber (Sentry, Honeybadger, ...) a
        # swallowed card failure would otherwise leave no trace at all.
        def report_error(error)
          Rails.logger.error do
            "[plutonium.dashboard] #{dashboard.class.name}##{card.key} failed to load: " \
              "#{error.class}: #{error.message}\n#{error.backtrace&.first(10)&.join("\n")}"
          end
          Rails.error.report(
            error,
            handled: true,
            source: "plutonium.dashboard",
            context: {dashboard: dashboard.class.name, card: card.key.to_s}
          )
        end

        def raise_card_errors?
          Rails.application.config.consider_all_requests_local
        end

        def render_error
          div(class: "pu-dashboard-card-error", role: "alert") do
            render Phlex::TablerIcons::AlertCircle.new(class: "size-4 shrink-0")
            span { t("plutonium.dashboard.card_error") }
          end
        end
      end
    end
  end
end

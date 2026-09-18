# frozen_string_literal: true

module Plutonium
  # Dashboards: a declarative page of metric, chart and free-form cards.
  #
  # A dashboard is a plain class (`app/dashboards/sales_dashboard.rb`) that
  # subclasses {Plutonium::Dashboard::Base} and declares its cards with the
  # class-level DSL. It is mounted in a portal (or the main app) with
  # `register_dashboard` in the routes, exactly like `register_wizard`:
  #
  #   class SalesDashboard < Plutonium::Dashboard::Base
  #     presents label: "Sales", icon: Phlex::TablerIcons::ChartBar
  #
  #     metric(:orders) { Order.count }
  #     chart(:revenue, type: :line, span: 8) { Order.group_by_day(:created_at).sum(:total) }
  #   end
  #
  #   AdminPortal::Engine.routes.draw do
  #     register_dashboard SalesDashboard, at: "sales"
  #   end
  #
  # Every card is loaded in its own lazy turbo frame, so the page renders
  # instantly and each card's queries run in a separate request.
  module Dashboard
    # Raised when a route names a dashboard class that is not loaded (never a
    # user-facing 404 in practice: the class is handed to `register_dashboard`).
    class UnknownDashboardError < StandardError; end

    # Raised by the card endpoint when the `:card` segment names no declared
    # card, or a card whose `condition:` hides it for this request. Mapped to
    # a 404 by the railtie so a hidden card is indistinguishable from a missing one.
    class UnknownCardError < StandardError; end

    # DOM id prefix of the per-card turbo frames, shared by the page and the
    # card endpoint.
    FRAME_PREFIX = "pu-dashboard-card"

    # Stands in for a policy result when `authorize?` denies entry, so the
    # standard ActionPolicy::Unauthorized rescue can render the message.
    AuthorizationDeniedResult = Struct.new(:message)
  end
end

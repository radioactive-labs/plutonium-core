# frozen_string_literal: true

module Plutonium
  module Dashboard
    # The controller concern behind `register_dashboard`. Mixed into a
    # portal-namespaced `DashboardsController` synthesized at route-draw time
    # (see {Plutonium::Routing::DashboardRegistration}), so it inherits the
    # portal's auth, entity scoping and layout exactly like a resource
    # controller. Define `<Portal>::DashboardsController` yourself (including
    # this module) to take over.
    #
    # Two actions: `show` renders the page with one lazy turbo frame per card,
    # and `card` answers a single frame. Both run `authorize?` on the dashboard;
    # `card` additionally rejects unknown and hidden cards with a 404.
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Core::Controller

      included do
        helper_method :current_user, :current_dashboard, :dashboard_card_path
      end

      class_methods do
        # The gem's shared partials (`plutonium/_flash`, ...) resolve through a
        # "plutonium" view prefix that a bare host has no ancestor to supply.
        def _prefixes
          @_dashboard_view_prefixes ||= (super | ["plutonium"])
        end
      end

      # GET the mount — the full page.
      def show
        authorize_dashboard!
        set_page_title(current_dashboard_class.label)
        render Plutonium::UI::Page::Dashboard.new(dashboard: current_dashboard)
      end

      # GET <mount>/cards/:card — one card, wrapped in its turbo frame.
      def card
        authorize_dashboard!
        card = current_dashboard.visible_card!(params[:card])
        render Plutonium::UI::Dashboard::Frame.new(dashboard: current_dashboard, card:)
      end

      private

      # Defers to the host's auth concern (a portal controller's Rodauth) and
      # is nil on a bare main-app host.
      def current_user
        defined?(super) ? super : nil
      end

      # The dashboard class rides the route defaults. Resolve it through the
      # allowlist of loaded dashboards rather than `constantize`-ing the raw
      # value, so a route param can never reach an arbitrary constant.
      def current_dashboard_class
        @current_dashboard_class ||= begin
          name = params.fetch(:dashboard_class).to_s
          Plutonium::Dashboard::Base.descendants.find { |klass| klass.name == name } ||
            raise(Plutonium::Dashboard::UnknownDashboardError, "unknown dashboard #{name.inspect}")
        end
      end

      def current_dashboard
        @current_dashboard ||= current_dashboard_class.new(view_context)
      end

      # `authorize?` false → 403 through the existing ActionPolicy::Unauthorized
      # rescue, with a fake result object so the exception needs no policy.
      def authorize_dashboard!
        return if current_dashboard.authorize?

        raise ::ActionPolicy::Unauthorized.new(
          current_dashboard,
          :authorize?,
          Plutonium::Dashboard::AuthorizationDeniedResult.new(I18n.t("plutonium.dashboard.authorization_denied"))
        )
      end

      # The card endpoint's path, threading the entity scope segment through so
      # the frame stays inside the tenant. Resolved by the route's
      # `dashboard_class` default, so `at:` / `as:` and a scope prefix are honoured.
      def dashboard_card_path(card)
        options = {card: card.key}
        options[scoped_entity_param_key] = params[scoped_entity_param_key] if scoped_to_entity?
        current_engine.routes.url_helpers.public_send(dashboard_card_route_helper, **options)
      end

      def dashboard_card_route_helper
        @dashboard_card_route_helper ||= begin
          name = Plutonium::Dashboard::RouteResolution.route_name(
            current_engine.routes, current_dashboard_class, action: "card"
          )
          raise "no register_dashboard route found for #{current_dashboard_class.name}" unless name

          :"#{name}_path"
        end
      end
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module Routing
    # Adds `register_dashboard` to the routing mapper, mirroring
    # `register_wizard`. A dashboard is portal-hosted: its routes are drawn
    # inside the engine's `routes.draw` block, so they inherit the portal's
    # scope, auth and layout, and dispatch to a synthesized portal-namespaced
    # `DashboardsController` that includes {Plutonium::Dashboard::Controller}.
    #
    # @example inside a portal engine's routes
    #   AdminPortal::Engine.routes.draw do
    #     register_dashboard HomeDashboard, at: "/"        # the portal root
    #     register_dashboard SalesDashboard, at: "sales"   # /dashboards/sales
    #   end
    #
    # Draws (portal-relative):
    #   GET /dashboards/sales             → DashboardsController#show   (sales_dashboard_path)
    #   GET /dashboards/sales/cards/:card → DashboardsController#card   (sales_dashboard_card_path)
    #
    # Every path sits under the `dashboards/` segment, so a dashboard can never
    # shadow (or be shadowed by) a `register_resource` route of the same name:
    # `at: "sales"` and a `Sale` resource would otherwise both claim `/sales`.
    # `prefix: nil` turns the segment off for a mount (`/sales`), and a string
    # swaps it (`prefix: "reports"` → `/reports/sales`).
    #
    # A root mount draws `root` for the page and `/dashboards/<name>/cards/:card`
    # for the cards, where `<name>` is `as:` or the class slug
    # (`HomeDashboard` → `home`).
    module DashboardRegistration
      DASHBOARD_CONTROLLER_NAME = "dashboards"
      DASHBOARD_PATH_SEGMENT = "dashboards"

      # @param dashboard_class [Class] a Plutonium::Dashboard::Base subclass
      # @param at [String] the path under the prefix; "/" (or "") mounts at the root
      # @param as [String, Symbol, nil] override the route helper prefix
      # @param prefix [String, nil] the leading path segment, "dashboards" by
      #   default; nil (or "") draws the mount at the bare `at:` path
      def register_dashboard(dashboard_class, at:, as: nil, prefix: DASHBOARD_PATH_SEGMENT)
        unless dashboard_class.is_a?(Class) && dashboard_class < Plutonium::Dashboard::Base
          raise ArgumentError, "register_dashboard: #{dashboard_class.inspect} must subclass Plutonium::Dashboard::Base"
        end

        engine = dashboard_route_engine
        raise ArgumentError, "register_dashboard: routes must be drawn on a Plutonium engine or the application" if engine.nil?

        mount_path = strip_slashes(at)
        prefix = strip_slashes(prefix)
        root = mount_path.empty?
        helper_name = (as || mount_path.presence || dashboard_class.route_name).to_s.tr("/", "_")
        defaults = {dashboard_class: dashboard_class.name}

        ensure_dashboard_controller!(engine)
        engine.dashboard_register.register(dashboard_class)

        controller = DASHBOARD_CONTROLLER_NAME
        if root
          get "/", to: "#{controller}#show", as: :root, defaults: defaults
        else
          get File.join(prefix, mount_path), to: "#{controller}#show", as: :"#{helper_name}_dashboard", defaults: defaults
        end

        cards_path = File.join(prefix, root ? helper_name : mount_path, "cards/:card")
        get cards_path, to: "#{controller}#card", as: :"#{helper_name}_dashboard_card", defaults: defaults
      end

      private

      # Resolve (creating if needed) the controller the routes dispatch to:
      # Possessive quantifiers (`/++`) so stripping the slashes can't backtrack:
      # a plain `/+\z` is O(n²) on a string of many slashes (rb/polynomial-redos).
      def strip_slashes(path)
        path.to_s.sub(%r{\A/++}, "").sub(%r{/++\z}, "")
      end

      # `<Portal>::DashboardsController` on a portal, `::DashboardsController`
      # on the main app. An app-defined class of that name wins.
      def ensure_dashboard_controller!(engine)
        portal_module = dashboard_portal_module(engine)
        if portal_module.nil?
          define_dashboard_controller(Object, "DashboardsController", "ApplicationController", nil)
        else
          define_dashboard_controller(
            portal_module,
            "DashboardsController",
            "#{portal_module.name}::PlutoniumController",
            "#{portal_module.name}::Concerns::Controller"
          )
        end
      end

      # Synthesize the controller unless the app defines one. A controller this
      # module synthesized earlier is rebuilt when its parent has been reloaded
      # (development), so it never keeps serving a stale `PlutoniumController`.
      def define_dashboard_controller(namespace, const_name, parent_name, concern_name)
        parent = parent_name.safe_constantize || ActionController::Base

        if namespace.const_defined?(const_name, false)
          existing = namespace.const_get(const_name, false)
          return existing unless existing.instance_variable_get(:@plutonium_synthesized) && existing.superclass != parent

          namespace.send(:remove_const, const_name)
        end

        klass = Class.new(parent) do
          include Plutonium::Dashboard::Controller
        end
        klass.instance_variable_set(:@plutonium_synthesized, true)
        namespace.const_set(const_name, klass)

        if concern_name && (concern = concern_name.safe_constantize)
          klass.include concern
        end
        klass
      end

      # The Plutonium engine owning this route set (mirrors RouteSetExtensions#engine).
      def dashboard_route_engine
        rs = respond_to?(:route_set) ? route_set : @set
        rs.respond_to?(:engine) ? rs.engine : nil
      end

      def dashboard_portal_module(engine)
        return nil if engine == Rails.application.class

        engine.module_parent
      end
    end
  end
end

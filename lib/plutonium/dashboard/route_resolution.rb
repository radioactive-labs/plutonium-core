# frozen_string_literal: true

module Plutonium
  module Dashboard
    # Resolves a `register_dashboard` mount's named routes from a route set by
    # the `dashboard_class` route default every dashboard route carries.
    #
    # The helper name is not derivable from the class: it comes from `at:` /
    # `as:`, and an entity-scoped portal prefixes it with the scope segment
    # (`organization_scoped_team_dashboard`). Looking the route up by its
    # default tracks whatever the registration actually drew.
    module RouteResolution
      module_function

      # @param route_set [ActionDispatch::Routing::RouteSet]
      # @param dashboard_class [Class]
      # @param action [String, Symbol] "show" or "card"
      # @return [Symbol, nil] the route name (e.g. :sales_dashboard_card)
      def route_name(route_set, dashboard_class, action:)
        route = route_set.routes.find do |r|
          d = r.defaults
          r.name.present? &&
            d[:action].to_s == action.to_s &&
            d[:dashboard_class].to_s == dashboard_class.name
        end
        route&.name&.to_sym
      end
    end
  end
end

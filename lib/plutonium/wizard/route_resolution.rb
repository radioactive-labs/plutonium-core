# frozen_string_literal: true

module Plutonium
  module Wizard
    # Resolves a `register_wizard` mount's named routes from a route set by the
    # `wizard_class` route default that every wizard route carries (§5.2/§5.3).
    #
    # `register_wizard` names its helpers from the mount path (`at:`) or an explicit
    # `as:`, NOT from the wizard class name — so `register_wizard W, at: "onboarding"`
    # draws `onboarding_wizard*`, regardless of `W`'s class. Re-deriving a slug from
    # the class name (as the gate once did) only works when the two happen to
    # coincide; everywhere a URL is built for a registered wizard, the route must be
    # looked up by the `wizard_class` default instead.
    #
    # Shared by {Plutonium::Wizard::Controller} (per-step URLs), {Gate} (the entry
    # redirect), and {Resume} (the in-progress listing), so all three track the
    # actual `at:`/`as:` used at registration.
    module RouteResolution
      module_function

      # The name of the route `register_wizard` drew for the given action and wizard
      # class within +route_set+, or nil if none. Actions: "launch" (the bare mount
      # → resolve/PRG to the run's step), "show" (GET a specific step).
      #
      # @param route_set [ActionDispatch::Routing::RouteSet]
      # @param wizard_class [Class]
      # @param action [String, Symbol] "launch" or "show"
      # @return [Symbol, nil] the route name (e.g. :onboarding_wizard_launch)
      def route_name(route_set, wizard_class, action:)
        route = route_set.routes.find do |r|
          d = r.defaults
          r.name.present? &&
            d[:action].to_s == action.to_s &&
            d[:wizard_class].to_s == wizard_class.name
        end
        route&.name&.to_sym
      end
    end
  end
end

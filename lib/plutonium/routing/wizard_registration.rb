# frozen_string_literal: true

module Plutonium
  module Routing
    # Adds `register_wizard` to the routing mapper, mirroring `register_resource`
    # (see {MapperExtensions}). A wizard is **portal-hosted** (§5.2): the routes are
    # drawn inside the portal engine's `routes.draw` block, so they inherit the
    # portal's scope/auth/layout, and they dispatch to a portal-namespaced wizard
    # controller that includes {Plutonium::Wizard::Controller} + the portal's own
    # controller concern.
    #
    # @example inside a portal engine's routes
    #   AdminPortal::Engine.routes.draw do
    #     register_wizard OnboardingWizard, at: "onboarding"
    #     register_resource ::User
    #   end
    #
    # Draws (portal-relative):
    #   GET  /onboarding(/:token)/:step  → <Portal>::WizardsController#show
    #   POST /onboarding(/:token)/:step  → <Portal>::WizardsController#update
    #
    # with `onboarding_wizard_path` / `_url` helpers.
    module WizardRegistration
      WIZARD_CONTROLLER_NAME = "wizards"

      # @param wizard_class [Class] a Plutonium::Wizard::Base subclass
      # @param at [String] the portal-relative base path for the wizard's steps
      # @param as [String, Symbol, nil] override the route helper name prefix
      def register_wizard(wizard_class, at:, as: nil)
        ensure_wizard_controller!(wizard_class)

        helper_name = (as || wizard_route_name(wizard_class)).to_s
        defaults = {wizard_class: wizard_class.name}

        scope path: at do
          get "(/:token)/:step", to: "#{WIZARD_CONTROLLER_NAME}#show",
            as: :"#{helper_name}_wizard", defaults: defaults
          post "(/:token)/:step", to: "#{WIZARD_CONTROLLER_NAME}#update",
            defaults: defaults
        end
      end

      private

      def wizard_route_name(wizard_class)
        wizard_class.name.demodulize.underscore.sub(/_wizard\z/, "")
      end

      # Resolve (creating if needed) the portal-namespaced wizard controller the
      # routes dispatch to. The portal engine isolates its namespace, so a route
      # `controller: "wizards"` resolves to `<PortalModule>::WizardsController`.
      # There is no hand-written file for it (unlike resource controllers, which
      # are scaffolded), so we synthesize it here — the same idea as
      # {Plutonium::Portal::DynamicControllers}, but triggered explicitly at route
      # draw time rather than via `const_missing`.
      def ensure_wizard_controller!(wizard_class)
        engine = wizard_route_engine
        return if engine.nil?

        portal_module = wizard_portal_module(engine)
        if portal_module.nil?
          # Main-app / non-namespaced mount: a top-level WizardsController is enough.
          define_wizard_controller(Object, "WizardsController", "PlutoniumController", nil)
          return
        end

        define_wizard_controller(
          portal_module,
          "WizardsController",
          "#{portal_module.name}::PlutoniumController",
          "#{portal_module.name}::Concerns::Controller"
        )
      end

      def define_wizard_controller(namespace, const_name, parent_name, concern_name)
        return if namespace.const_defined?(const_name, false)

        parent = parent_name.safe_constantize || ::PlutoniumController
        klass = Class.new(parent) do
          include Plutonium::Wizard::Controller
        end
        namespace.const_set(const_name, klass)

        if concern_name && (concern = concern_name.safe_constantize)
          klass.include concern
        end
        klass
      end

      # The Plutonium engine owning this route set (mirrors RouteSetExtensions#engine).
      def wizard_route_engine
        rs = respond_to?(:route_set) ? route_set : @set
        rs.respond_to?(:engine) ? rs.engine : nil
      end

      # The portal module (e.g. AdminPortal) for a `SomePortal::Engine`, or nil for
      # the main application.
      def wizard_portal_module(engine)
        return nil if engine == Rails.application.class

        engine.module_parent
      end
    end
  end
end

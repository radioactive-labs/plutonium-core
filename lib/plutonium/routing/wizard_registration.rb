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

      # Tracks which public wizard route blocks have already been appended to the
      # main app route set, so re-draws don't stack duplicate (named) routes.
      class << self
        attr_accessor :appended_public_wizards
      end

      # @param wizard_class [Class] a Plutonium::Wizard::Base subclass
      # @param at [String] the portal-relative base path for the wizard's steps
      # @param as [String, Symbol, nil] override the route helper name prefix
      # @param public [Boolean, nil] mount on a PUBLIC (unauthenticated) route
      #   outside the portal's auth constraint, for an `anonymous` (guest) wizard.
      #   Defaults to the wizard's own `anonymous?` flag. A non-`anonymous` wizard
      #   may not be mounted public; an `anonymous` wizard may not be mounted
      #   authenticated (its whole point is pre-login access). See §4.5.
      def register_wizard(wizard_class, at:, as: nil, public: nil)
        # A CONTEXT anchor (`anchored via: :method`) is portal-level: the anchor is
        # resolved by calling a controller method, needs no URL `:id`, and is
        # IDOR-safe (trusted context) — so it CAN mount here. Only a TYPE anchor
        # (`with:`-only, resolved from the URL `:id`) is rejected, because it needs
        # the resource controller's scoped, policy-gated `resource_record!`.
        if wizard_class.anchored? && !wizard_class.anchored_via?
          raise ArgumentError,
            "register_wizard #{wizard_class.name} — `with:`-anchored wizards are not " \
            "mounted portal-level. Register them on the anchored resource's definition " \
            "with the `wizard` macro, which auto-mounts a record action whose anchor is " \
            "resolved through the resource controller's scoped, policy-gated " \
            "`resource_record!`. (A `via:`-anchored wizard mounts here fine.)"
        end

        # Default the mount kind to the wizard's `anonymous?` flag, and reject
        # contradictions (§4.5): an `anonymous` wizard NEEDS a public route
        # (pre-login); a non-`anonymous` wizard MUST stay behind portal auth.
        is_public = public.nil? ? wizard_class.anonymous? : !!public
        if is_public && !wizard_class.anonymous?
          raise ArgumentError,
            "register_wizard #{wizard_class.name}, public: true — only an `anonymous` " \
            "wizard may be mounted public. Add the `anonymous` macro to the wizard, or " \
            "drop `public:`."
        end
        if !is_public && wizard_class.anonymous?
          raise ArgumentError,
            "register_wizard #{wizard_class.name} — an `anonymous` wizard must be mounted " \
            "public (it runs pre-login). Pass `public: true` (it is the default for " \
            "`anonymous` wizards)."
        end

        return register_public_wizard(wizard_class, at:, as:) if is_public

        ensure_wizard_controller!(wizard_class)

        # The helper name defaults to the mount path (`at:`), so
        # `register_wizard W, at: "onboarding"` yields `onboarding_wizard_path`.
        # `as:` overrides it; the wizard's own route name is the final fallback.
        helper_name = (as || at.presence || wizard_route_name(wizard_class)).to_s.tr("/", "_")
        defaults = {wizard_class: wizard_class.name}

        scope path: at do
          # Canonical launch: GET the bare mount → resolve/mint the run and PRG to
          # its first (or resumed) step, with the token already in the URL. This is
          # the shareable entry point; `wizard_step_url` builds the stepped URLs.
          get "/", to: "#{WIZARD_CONTROLLER_NAME}#launch",
            as: :"#{helper_name}_wizard_launch", defaults: defaults
          get "(/:token)/:step", to: "#{WIZARD_CONTROLLER_NAME}#show",
            as: :"#{helper_name}_wizard", defaults: defaults
          post "(/:token)/:step", to: "#{WIZARD_CONTROLLER_NAME}#update",
            defaults: defaults
        end
      end

      private

      # Mount an `anonymous` wizard on a PUBLIC (unauthenticated) route (§4.5).
      #
      # Portal engines are mounted INSIDE the host's auth constraint
      # (`constraints Rodauth::Rails.authenticate(:user) { mount ... }`), so a
      # route drawn in the engine is unreachable pre-login. A guest wizard must
      # therefore be drawn on the MAIN application's route set, OUTSIDE that
      # constraint. We append to `Rails.application.routes` so the public route is
      # added after (and independent of) the engine mount.
      #
      # The route dispatches to a synthesized top-level `WizardsController` that
      # includes the full Plutonium controller stack + `Plutonium::Auth::Public`
      # (so `current_user` is the guest sentinel) + {Plutonium::Wizard::Controller}.
      def register_public_wizard(wizard_class, at:, as:)
        ensure_public_wizard_controller!

        helper_name = (as || at.presence || wizard_route_name(wizard_class)).to_s.tr("/", "_")
        defaults = {wizard_class: wizard_class.name}
        mount_path = at.to_s.sub(%r{\A/}, "")

        # `Rails.application.routes.append` blocks are RETAINED and re-run on every
        # route reload — so append a given wizard's block at most once, keyed by its
        # route name. Re-drawing the engine routes (boot, reload, multiple portals)
        # otherwise stacks duplicate blocks → "route name already in use".
        registered = (Plutonium::Routing::WizardRegistration.appended_public_wizards ||= Set.new)
        return unless registered.add?(:"#{helper_name}_wizard")

        Rails.application.routes.append do
          scope path: mount_path do
            get "/", to: "wizards#launch",
              as: :"#{helper_name}_wizard_launch", defaults: defaults
            get "(/:token)/:step", to: "wizards#show",
              as: :"#{helper_name}_wizard", defaults: defaults
            post "(/:token)/:step", to: "wizards#update",
              defaults: defaults
          end
        end
      end

      # Synthesize the top-level public `WizardsController` once. Unlike the portal
      # controller (built on the portal's authenticated `PlutoniumController`), the
      # public one is built directly on the Plutonium controller stack with
      # `Plutonium::Auth::Public`, so it has the rendering/scoping infra a wizard
      # needs WITHOUT requiring a login.
      def ensure_public_wizard_controller!
        return if Object.const_defined?(:WizardsController, false)

        # Inherit from the host's top-level `PlutoniumController` so the controller
        # lookup chain contributes the `plutonium` view-path prefix — that's what
        # resolves the gem's shared partials (`plutonium/_flash`, etc.) the layout
        # renders. Falling back to ApplicationController would lose that prefix.
        base = "PlutoniumController".safe_constantize ||
          "ApplicationController".safe_constantize ||
          ActionController::Base
        klass = Class.new(base) do
          include Plutonium::Core::Controller
          include Plutonium::Auth::Public
          include Plutonium::Wizard::Controller

          # A guest wizard renders FULL-PAGE without the resource shell (no sidebar /
          # resource header / user menu — none of which make sense pre-login). Use
          # the standalone layout (just the base HTML document); turbo-frame
          # requests still drop the layout entirely (see Driving#wizard_modal_render_options).
          layout -> { turbo_frame_request? ? false : "plutonium_standalone" }
        end
        Object.const_set(:WizardsController, klass)
      end

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

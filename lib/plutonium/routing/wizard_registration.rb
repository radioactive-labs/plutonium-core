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

      # Tracks public wizard mounts already appended to the main app route set, so
      # re-draws (boot, reload, multiple portals) don't stack duplicate named
      # routes. Keyed by the wizard CLASS NAME (not the helper name) so two distinct
      # anonymous wizards never collapse into one entry — a helper-name collision
      # between different wizards is a hard error (see {#register_public_wizard}),
      # not a silent drop. Maps `wizard_class.name => helper_name`.
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
      # @param layout [Symbol, String, nil] the Rails layout this mount renders in —
      #   a layout NAME, exactly like the controller `layout` macro: `:basic` (the
      #   bare `BasicLayout`, e.g. an onboarding screen), `:resource` (the standard
      #   shell), or any app layout. Only meaningful for `register_wizard` mounts;
      #   resource-defined (`wizard` macro) wizards are always embedded. Defaults by
      #   context (portal → the resource shell, main-app → `:basic`); turbo-frame
      #   requests are always layout-less regardless.
      def register_wizard(wizard_class, at:, as: nil, public: nil, layout: nil)
        # The wizard subsystem is opt-in (`config.wizards.enabled`). When disabled,
        # draw no routes — its tables/migrations are skipped too, so a mounted route
        # couldn't work anyway. Warn rather than fail silently, so a
        # registered-but-disabled wizard is discoverable instead of a mystery 404.
        unless Plutonium.configuration.wizards.enabled
          Rails.logger.warn { "[Plutonium::Wizard] not registering routes for #{wizard_class} — config.wizards.enabled is false" }
          return
        end

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

        return register_public_wizard(wizard_class, at:, as:, layout:) if is_public

        ensure_wizard_controller!(wizard_class)

        # The helper name defaults to the mount path (`at:`), so
        # `register_wizard W, at: "onboarding"` yields `onboarding_wizard_path`.
        # `as:` overrides it; the wizard's own route name is the final fallback.
        helper_name = (as || at.presence || wizard_route_name(wizard_class)).to_s.tr("/", "_")
        defaults = wizard_route_defaults(wizard_class, layout)

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

      # Route defaults carried on every wizard route: the wizard class (resolves the
      # wizard at request time) and, when explicitly set, the `layout`
      # (a layout name). An unset layout is omitted — the driving layer then
      # defaults it by context (portal → the resource shell, main-app → `:basic`). The
      # layout rides the route (not a controller-class setting) because one
      # synthesized controller serves many mounts, so the per-mount value can't live
      # on the controller.
      def wizard_route_defaults(wizard_class, layout)
        defaults = {wizard_class: wizard_class.name}
        defaults[:wizard_layout] = layout.to_s if layout
        defaults
      end

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
      def register_public_wizard(wizard_class, at:, as:, layout: nil)
        ensure_public_wizard_controller!

        helper_name = (as || at.presence || wizard_route_name(wizard_class)).to_s.tr("/", "_")
        defaults = wizard_route_defaults(wizard_class, layout)
        mount_path = at.to_s.sub(%r{\A/}, "")

        # `Rails.application.routes.append` blocks are RETAINED and re-run on every
        # route reload — so append a given wizard's block at most once. Key by the
        # wizard CLASS (not the helper name) so re-drawing the SAME wizard is a no-op
        # while two DIFFERENT wizards are never silently collapsed.
        registered = (Plutonium::Routing::WizardRegistration.appended_public_wizards ||= {})

        # Two distinct public wizards sharing a helper name (same `at:`/`as:`) would
        # draw the same route name → Rails "route name already in use", or worse, a
        # silent drop. Fail loudly with a fix instead.
        clash = registered.find { |klass_name, helper| helper == helper_name && klass_name != wizard_class.name }
        if clash
          raise ArgumentError,
            "register_wizard #{wizard_class.name}, at: #{at.inspect} — the route helper " \
            "`#{helper_name}_wizard` is already used by #{clash.first}. Give one of them a " \
            "distinct `at:` or `as:`."
        end

        return unless registered[wizard_class.name].nil?
        registered[wizard_class.name] = helper_name

        Rails.application.routes.append do
          scope path: mount_path do
            get "/", to: "public_wizards#launch",
              as: :"#{helper_name}_wizard_launch", defaults: defaults
            get "(/:token)/:step", to: "public_wizards#show",
              as: :"#{helper_name}_wizard", defaults: defaults
            post "(/:token)/:step", to: "public_wizards#update",
              defaults: defaults
          end
        end
      end

      # Synthesize the top-level public `PublicWizardsController` once. Unlike the
      # portal controller (built on the portal's authenticated `PlutoniumController`),
      # the public one is built directly on the Plutonium controller stack with
      # `Plutonium::Auth::Public`, so it has the rendering/scoping infra a wizard
      # needs WITHOUT requiring a login.
      #
      # It is a DISTINCT const from the authenticated main-app `::WizardsController`
      # (see {#ensure_wizard_controller!}): the two must not share a controller, or a
      # public (guest) and an authenticated main-app wizard in the same app would
      # collapse onto whichever was synthesized first — an authenticated main-app
      # wizard would then run through `Auth::Public` and reject every logged-in user.
      def ensure_public_wizard_controller!
        return if Object.const_defined?(:PublicWizardsController, false)

        # Build on a BARE base, decoupled from the app's `::PlutoniumController`
        # (which portals inherit and may carry auth). `Plutonium::Wizard::Controller`
        # brings the full rendering stack — including `Core::Controller`'s gem
        # view-path, which resolves the shared partials (`plutonium/_flash`, etc.) —
        # so no PlutoniumController inheritance is needed for that.
        base = "ApplicationController".safe_constantize || ActionController::Base
        klass = Class.new(base) do
          # `Auth::Public` provides the guest `current_user`; an `anonymous` wizard
          # ignores it for identity (session-token keyed) but the host still needs a
          # `current_user` defined.
          include Plutonium::Auth::Public
          include Plutonium::Wizard::Controller
        end
        Object.const_set(:PublicWizardsController, klass)
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
          # Main-app / non-namespaced mount. Synthesize a BARE top-level
          # WizardsController (ApplicationController + the wizard module) — it is NOT
          # rooted in the app's `::PlutoniumController` (portals inherit that, so auth
          # there would leak). A bare synthesized controller has NO auth, so a
          # public/`anonymous` wizard works as-is; an AUTHENTICATED main-app wizard
          # requires the app to define its own `::WizardsController` (with its auth
          # concern), which the const-check below picks up instead of synthesizing.
          #
          # This rhymes with `register_resource` ("the app owns the controller") but
          # isn't identical: `register_resource` never synthesizes a fallback, so a
          # missing controller is a loud routing/constant error; here the fallback is
          # auth-less, so a missing override for an authenticated wizard fails QUIETER
          # — every user is bounced to login rather than erroring. Covered by the
          # skill docs + main_app_wizard_test so it's an explicit, tested edge.
          define_wizard_controller(Object, "WizardsController", "ApplicationController", nil)
          return
        end

        define_wizard_controller(
          portal_module,
          "WizardsController",
          "#{portal_module.name}::PlutoniumController",
          "#{portal_module.name}::Concerns::Controller"
        )
      end

      # Synthesize a wizard controller unless one is already defined (the app's
      # override wins — define `<Portal>::WizardsController` / `::WizardsController`
      # to take over). `Plutonium::Wizard::Controller` brings the full rendering
      # stack, so the parent only needs to supply auth/scope (a portal's
      # PlutoniumController) or nothing (a bare main-app base).
      def define_wizard_controller(namespace, const_name, parent_name, concern_name)
        return if namespace.const_defined?(const_name, false)

        parent = parent_name.safe_constantize || ActionController::Base
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

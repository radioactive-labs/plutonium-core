# frozen_string_literal: true

module Plutonium
  module Wizard
    # The standalone portal-hosted controller concern for portal-level wizards
    # registered with `register_wizard` (§5.2). It is mixed into a portal-
    # namespaced controller (see {Plutonium::Routing::WizardRegistration}), so it
    # inherits the portal's auth, tenant scoping entity, layout, and Phlex
    # rendering exactly like a resource controller.
    #
    # All runner-driving logic lives in {Plutonium::Wizard::Driving} (shared with
    # the resource-mounted {Plutonium::Resource::Controllers::WizardActions}). This
    # concern only adapts that logic to the standalone surface: the `show`/`update`
    # actions, the wizard class carried as a route default, no anchor (portal-level
    # wizards are non-anchored — anchored wizards mount on the resource controller),
    # and the per-step URL built from the named route helper `register_wizard` draws.
    #
    # Identity (§4): a guest (`anonymous`) run's per-run id lives in the Rails
    # session, namespaced per wizard (no cookie, no TTL); it is cleared on
    # completion and auto-cleared on login/logout (Rodauth `reset_session`). An
    # authenticated repeatable run carries its per-run id in the URL `:token`
    # segment, guarded by owner-scoping; neither crosses the auth boundary
    # mid-flow (§4.5).
    module Controller
      extend ActiveSupport::Concern
      # The complete include surface for a standalone wizard controller: the
      # Plutonium rendering/scoping stack PLUS the wizard driving. Including this
      # one module yields a fully renderable wizard controller, so the synthesizer
      # and any app override (`class WizardsController < MyAuthBase; include
      # Plutonium::Wizard::Controller; end`) both get everything. Re-including Core
      # on a host that already has it (a portal controller) is a harmless no-op.
      include Plutonium::Core::Controller
      include Plutonium::Wizard::Driving

      included do
        helper_method :current_user
      end

      class_methods do
        # The gem's shared partials (`plutonium/_flash`, …) are looked up by a
        # "plutonium" view prefix, which normally comes from inheriting a controller
        # whose `controller_path` is "plutonium" (the app's `PlutoniumController`). A
        # bare host (a main-app / public wizard rooted in `ActionController::Base`)
        # has no such ancestor, so contribute the prefix here — making the module
        # self-sufficient and the "main-app can be bare" path actually work.
        def _prefixes
          @_wizard_view_prefixes ||= (super | ["plutonium"])
        end
      end

      # GET the bare mount — resolve/mint the run and redirect to its step.
      def launch
        wizard_launch
      end

      # GET .../:step — render the current step.
      def show
        wizard_show
      end

      # POST .../:step — advance / back / cancel.
      def update
        wizard_update
      end
 
      # DELETE .../:token
      def discard
        wizard_discard
      end

      private

      # Identity for a standalone wizard host. Defers to the host's own auth
      # concern when present — a portal controller's `Rodauth(:account)`, or an
      # app-defined `::WizardsController`'s — and is `nil` on a bare host (a public
      # mount, or a misconfigured authenticated main-app wizard with no auth
      # controller). An `anonymous` wizard never consults this; a non-anonymous
      # wizard on a bare host resolves `nil` and is rejected by
      # `require_wizard_authentication!`.
      def current_user
        defined?(super) ? super : nil
      end

      # The wizard class is carried as a route default (see WizardRegistration),
      # so it is a server-set path parameter. Resolve it through an ALLOWLIST of
      # the loaded wizard classes rather than `constantize`-ing the raw value:
      # every standalone wizard route is drawn by handing `register_wizard` the
      # class object, so by the time its route matches the class is loaded and
      # registered as a `Base` descendant. Matching by name can therefore only
      # ever return an actual wizard — it never triggers resolution of an
      # arbitrary constant (the `constantize`-on-params code-execution surface).
      def current_wizard_class
        @current_wizard_class ||= begin
          name = params.fetch(:wizard_class).to_s
          Plutonium::Wizard::Base.descendants.find { |klass| klass.name == name } ||
            raise(Plutonium::Wizard::UnknownWizardError, "unknown wizard #{name.inspect}")
        end
      end

      # Portal-level wizards are either non-anchored or CONTEXT-anchored
      # (`anchored via: :method`, §3). A `with:`-only (TYPE) anchor mounts on the
      # resource controller instead (see {WizardActions}), where the anchor is
      # resolved through the scoped, policy-gated `resource_record!` — never an
      # unscoped `find_by`, which would be a cross-tenant IDOR.
      #
      # For a CONTEXT anchor we call the declared method on this controller; a nil
      # result is a programming error (the wizard declared itself anchored).
      def resolved_wizard_anchor
        klass = current_wizard_class
        return nil unless klass.anchored_via?

        record = send(klass.anchor_via)
        if record.nil?
          raise Plutonium::Wizard::NotAnchoredError,
            "#{klass.name} resolves its anchor via `#{klass.anchor_via}`, which returned nil"
        end
        assert_anchor_type!(klass, record)
        record
      end

      # When a CONTEXT anchor also declares `with:` types, type-assert the result.
      def assert_anchor_type!(klass, record)
        types = klass.anchor_types
        return if types.nil?
        return if types.any? { |t| record.is_a?(t) }

        raise Plutonium::Wizard::NotAnchoredError,
          "#{klass.name} anchor resolved to #{record.class} but expects one of " \
          "#{types.join(", ")}"
      end

      # Build the GET URL for a given step of this wizard, preserving the
      # `:token` segment. Built through the named route helper that
      # `register_wizard` draws (resolved from the current engine's route set by
      # the wizard class, so `at:`/`as:` overrides are honored) — never
      # string-surgery on `request.path`, so the URL is always a same-host,
      # route-validated path.
      def wizard_step_url(step_key)
        url_options = {step: step_key}
        token = wizard_url_token
        url_options[:token] = token if token.present?
        # An entity-scoped portal's wizard routes carry the scope path segment
        # (e.g. `:organization_scoped`); thread it through from the request so the
        # generated URL stays inside the tenant.
        if scoped_to_entity?
          url_options[scoped_entity_param_key] = params[scoped_entity_param_key]
        end
        current_engine.routes.url_helpers.public_send(wizard_step_url_helper, **url_options)
      end

      # The `<name>_wizard_path` helper for this wizard's standalone mount. Found
      # by the GET route `register_wizard` draws (named `:"#{helper}_wizard"`,
      # carrying the `wizard_class` route default) so the lookup tracks the actual
      # `at:`/`as:` used at registration rather than re-deriving a slug.
      def wizard_step_url_helper
        @wizard_step_url_helper ||= begin
          name = Plutonium::Wizard::RouteResolution.route_name(
            current_engine.routes, current_wizard_class, action: "show"
          )
          raise "no register_wizard route found for #{current_wizard_class.name}" unless name
 
          :"#{name}_path"
        end
      end
 
      def wizard_launch_url
        url_options = {}
        if scoped_to_entity?
          url_options[scoped_entity_param_key] = params[scoped_entity_param_key]
        end
        helper_name = wizard_step_url_helper.to_s.sub(/_path\z/, "_launch_path").to_sym
        current_engine.routes.url_helpers.public_send(helper_name, **url_options)
      end
    end
  end
end

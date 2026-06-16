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
    # Identity (§4): non-anchored / pre-auth flows carry a `token` in a signed
    # cookie (minted on first GET when absent); the cookie is cleared on completion.
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Wizard::Driving

      # Back-compat shim: the cookie key helper used to live here.
      def self.token_cookie_key(wizard_class)
        Plutonium::Wizard::Driving.token_cookie_key(wizard_class)
      end

      # GET .../:step — render the current step.
      def show
        wizard_show
      end

      # POST .../:step — advance / back / cancel.
      def update
        wizard_update
      end

      private

      # The wizard class is carried as a route default (see WizardRegistration).
      def current_wizard_class
        @current_wizard_class ||= params.fetch(:wizard_class).to_s.constantize
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
        url_options[:token] = params[:token] if params[:token].present?
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
          route = current_engine.routes.routes.find do |r|
            d = r.defaults
            r.name.present? &&
              d[:action].to_s == "show" &&
              d[:wizard_class].to_s == current_wizard_class.name
          end
          raise "no register_wizard route found for #{current_wizard_class.name}" unless route

          :"#{route.name}_path"
        end
      end
    end
  end
end

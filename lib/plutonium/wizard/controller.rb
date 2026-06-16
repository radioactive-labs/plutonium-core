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

      # Portal-level wizards are non-anchored. Anchored wizards mount on the
      # resource controller (see {WizardActions}), where the anchor is resolved
      # through the scoped, policy-gated `resource_record!` — never an unscoped
      # `find_by`, which would be a cross-tenant IDOR.
      def resolved_wizard_anchor
        nil
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

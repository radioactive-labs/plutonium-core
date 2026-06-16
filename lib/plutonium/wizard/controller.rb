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
    # and the per-step URL derived from the request path.
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
      # `:token` segment. Derived from the current request path by swapping the
      # trailing `:step` segment.
      def wizard_step_url(step_key)
        step = step_key.to_s
        current = params[:step].to_s
        path = request.path
        base = current.present? ? path.delete_suffix("/#{current}") : path
        "#{base}/#{step}"
      end
    end
  end
end

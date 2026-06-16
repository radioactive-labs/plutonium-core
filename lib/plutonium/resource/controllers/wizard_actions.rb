# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Resource-mounted wizard launch surface (§5.1 / Fix A). Anchored (and
      # non-anchored) wizards registered via the `wizard` definition macro are
      # auto-mounted as member/collection routes on the resource's OWN controller —
      # the same way interactive record/resource actions are (see
      # {InteractiveActions}). This is what makes the anchor IDOR-safe:
      #
      # - **member** actions (`wizard_record_action` / `commit_wizard_record_action`)
      #   resolve the anchor through the resource controller's scoped, policy-gated
      #   `resource_record!` — never an unscoped `find_by(id:)`. A record outside the
      #   portal's authorized scope 404s, exactly like a record action.
      # - **collection** actions (`wizard_resource_action` /
      #   `commit_wizard_resource_action`) have no anchor (create flows).
      #
      # The runner-driving flow itself lives in {Plutonium::Wizard::Driving} (shared
      # with the standalone {Plutonium::Wizard::Controller}); this concern only
      # supplies the surface hooks (wizard class from the definition's registry, the
      # anchor from `resource_record!`, the per-step URL) and the action authorization
      # (the resource action policy predicate, mirroring interactive actions).
      module WizardActions
        extend ActiveSupport::Concern
        include Plutonium::Wizard::Driving

        included do
          before_action :validate_wizard_action!, only: %i[
            wizard_record_action commit_wizard_record_action
            wizard_resource_action commit_wizard_resource_action
          ]

          before_action :authorize_wizard_record_action!, only: %i[
            wizard_record_action commit_wizard_record_action
          ]

          before_action :authorize_wizard_resource_action!, only: %i[
            wizard_resource_action commit_wizard_resource_action
          ]
        end

        # GET /resources/:id/wizards/:wizard_name/(:token)/:step
        def wizard_record_action
          wizard_show
        end

        # POST /resources/:id/wizards/:wizard_name/(:token)/:step
        def commit_wizard_record_action
          wizard_update
        end

        # GET /resources/wizards/:wizard_name/(:token)/:step
        def wizard_resource_action
          skip_verify_current_authorized_scope!
          wizard_show
        end

        # POST /resources/wizards/:wizard_name/(:token)/:step
        def commit_wizard_resource_action
          skip_verify_current_authorized_scope!
          wizard_update
        end

        private

        # --- surface hooks (override Driving) ---

        # The wizard class for this request, resolved from the resource definition's
        # registry by the `:wizard_name` route segment.
        def current_wizard_class
          @current_wizard_class ||= current_wizard_registration.fetch(:wizard_class)
        end

        # The anchor for member (record) actions is the scoped, policy-gated record
        # — the IDOR-safe path. Member routes carry `:id`; collection (create) routes
        # don't, and have no anchor.
        def resolved_wizard_anchor
          return nil if params[:id].blank?

          resource_record!
        end

        # Build the GET URL for a given step, preserving the `:id` (member),
        # `:wizard_name`, and `:token` segments. Built through `resource_url_for`
        # with the `wizard:` kwarg (mirroring how interactions build their URLs via
        # `resource_url_for(..., interaction:)`) — never string-surgery on
        # `request.path`, so the URL is always a same-host, route-validated path.
        def wizard_step_url(step_key)
          resource_url_for(
            wizard_url_subject,
            wizard: current_wizard_name,
            step: step_key,
            **wizard_token_param
          )
        end

        # The URL anchor: the scoped record for member (record) actions, the
        # resource class for collection (resource) actions.
        def wizard_url_subject
          params[:id].present? ? resource_record! : resource_class
        end

        def current_wizard_name
          params[:wizard_name]
        end

        # Carry the `:token` segment for an authenticated repeatable (tokened) run,
        # so a fresh GET resumes rather than forks (§4.5). Guest/keyed runs add no
        # URL token (see Driving#wizard_url_token).
        def wizard_token_param
          token = wizard_url_token
          token.present? ? {token: token} : {}
        end

        # --- registry / authorization ---

        def registered_wizards
          @registered_wizards ||= current_definition.class.registered_wizards
        end

        def current_wizard_registration
          registered_wizards.fetch(params[:wizard_name]&.to_sym)
        end

        def validate_wizard_action!
          key = params[:wizard_name]&.to_sym
          unless registered_wizards.key?(key)
            raise ::AbstractController::ActionNotFound, "Unknown wizard '#{key}'"
          end
        end

        # Mirror interactive record-action authorization: gate via the resource
        # action policy predicate named after the wizard key (e.g. `configure?`).
        def authorize_wizard_record_action!
          authorize_current! resource_record!, to: :"#{params[:wizard_name]}?"
        end

        # Mirror interactive resource-action authorization: gate via the resource
        # class action policy predicate (e.g. `onboard?`).
        def authorize_wizard_resource_action!
          authorize_current! resource_class, to: :"#{params[:wizard_name]}?"
        end
      end
    end
  end
end

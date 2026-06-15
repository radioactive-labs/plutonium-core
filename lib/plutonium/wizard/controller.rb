# frozen_string_literal: true

module Plutonium
  module Wizard
    # The single portal-hosted controller concern driving every wizard (§6). It is
    # mixed into a portal-namespaced controller (see
    # {Plutonium::Routing::WizardRegistration}), so it inherits the portal's auth,
    # tenant scoping entity, layout, and Phlex rendering exactly like a resource
    # controller.
    #
    # Per request it resolves the wizard instance (URL `:step`/optional `:token` +
    # `current_user` as owner + the portal `scoped_entity` as scope + `:id` as
    # anchor for resource-attached wizards), builds the {Runner}, checks entry
    # authorization, and:
    #
    # - GET `#show` renders the current step (minimal form for now — Task 6 builds
    #   the real stepper/review UI). A prior finalize's `redirect_step` bounces.
    # - POST `#update` dispatches on `params[:_direction]` — `back`/`cancel`/(advance
    #   + finalize on the last step) — mirroring the interactive-action commit flow.
    #
    # Identity (§4): non-anchored / pre-auth flows carry a `token` in a signed
    # cookie (minted on first GET when absent); the cookie is cleared on completion.
    module Controller
      extend ActiveSupport::Concern

      # Signed-cookie key holding the per-(wizard) token for non-anchored flows.
      def self.token_cookie_key(wizard_class)
        :"pu_wizard_#{wizard_class.name.underscore.tr("/", "_")}"
      end

      # GET .../:step — render the current step.
      def show
        runner = build_wizard_runner
        authorize_wizard_entry!(runner)

        # A prior finalize may have stored a completeness gap; bounce to it.
        if (target = wizard_redirect_step)
          return redirect_to wizard_step_url(target), status: :see_other
        end

        @wizard_runner = runner
        render_wizard_step(runner)
      end

      # POST .../:step — advance / back / cancel.
      def update
        runner = build_wizard_runner
        authorize_wizard_entry!(runner)
        @wizard_runner = runner

        if params[:pre_submit]
          return render_wizard_step(runner, status: :unprocessable_content)
        end

        result =
          case params[:_direction].to_s
          when "back"
            runner.back
          when "cancel"
            runner.cancel
            return redirect_to wizard_exit_url, status: :see_other
          else
            advance_or_finalize(runner)
          end

        respond_to_wizard_result(runner, result)
      end

      private

      # Advance the current step; if the POSTed step is the last visible step,
      # finalize. The last visible step is the terminal `review` (no fields), so
      # finalize runs directly; otherwise validate + stage + move the cursor.
      def advance_or_finalize(runner)
        return runner.finalize if wizard_posting_last_step?(runner)

        runner.advance(params[:step], wizard_params)
      end

      # Whether the step being POSTed is the last visible step (so Next → Finish).
      # Computed BEFORE advancing, since advance moves the cursor past it.
      def wizard_posting_last_step?(runner)
        last = runner.visible_path.last
        last && last.key.to_s == params[:step].to_s
      end

      def respond_to_wizard_result(runner, result)
        if result.completed?
          return complete_wizard!(result)
        end

        if (target = result.redirect_step)
          return redirect_to wizard_step_url(target), status: :see_other
        end

        if result.ok?
          redirect_to wizard_step_url(runner.current_step&.key), status: :see_other
        else
          @wizard_errors = result.errors
          render_wizard_step(runner, status: :unprocessable_content)
        end
      end

      # PRG out of a completed wizard: clear the signed token cookie and redirect to
      # the outcome value's URL (or the portal root as a fallback).
      def complete_wizard!(result)
        cookies.delete(Plutonium::Wizard::Controller.token_cookie_key(current_wizard_class))
        redirect_to wizard_completion_url(result.value), status: :see_other
      end

      # --- rendering (minimal; Task 6 replaces with the real page/stepper) ---

      def render_wizard_step(runner, status: :ok)
        render(
          Plutonium::UI::Page::Wizard.new(
            runner:,
            step_url: wizard_step_url(runner.current_step&.key),
            errors: @wizard_errors
          ),
          status:,
          **wizard_modal_render_options
        )
      end

      def wizard_modal_render_options
        helpers.current_turbo_frame.present? ? {layout: false} : {}
      end

      # --- runner construction ---

      def build_wizard_runner
        Plutonium::Wizard::Runner.new(
          wizard_class: current_wizard_class,
          store: wizard_store,
          instance_key: resolved_wizard_instance_key,
          view_context:,
          owner: current_user,
          anchor: resolved_wizard_anchor,
          scope: resolved_wizard_scope,
          token: resolved_wizard_token
        )
      end

      def wizard_store
        Plutonium::Wizard::Store::ActiveRecord.new
      end

      # The wizard class is carried as a route default (see WizardRegistration).
      def current_wizard_class
        @current_wizard_class ||= params.fetch(:wizard_class).to_s.constantize
      end

      def resolved_wizard_instance_key
        Plutonium::Wizard::InstanceKey.for(
          wizard: current_wizard_class.name,
          scope: resolved_wizard_scope,
          anchor: resolved_wizard_anchor,
          token: resolved_wizard_token,
          owner: current_user
        )
      end

      # Anchored (resource-attached) wizards bind the anchor from the URL `:id`.
      def resolved_wizard_anchor
        return unless current_wizard_class.anchored?
        return @resolved_wizard_anchor if defined?(@resolved_wizard_anchor)

        @resolved_wizard_anchor = wizard_anchor_from_id
      end

      def wizard_anchor_from_id
        id = params[:id]
        return if id.blank?

        klass = current_wizard_class.anchor_types&.first
        klass&.find_by(id:)
      end

      # The portal scoping entity (tenant) when the portal is entity-scoped (§4 /
      # §8 multi-tenancy); nil otherwise.
      def resolved_wizard_scope
        return unless scoped_to_entity?

        current_scoped_entity
      end

      # The identity principal for non-anchored / pre-auth flows (§4). Anchored
      # wizards need no token (the anchor disambiguates). For others, read the
      # signed cookie, minting one when absent so concurrent/pre-auth instances
      # stay distinct and resumable.
      def resolved_wizard_token
        return if current_wizard_class.anchored?
        return @resolved_wizard_token if defined?(@resolved_wizard_token)

        key = Plutonium::Wizard::Controller.token_cookie_key(current_wizard_class)
        token = params[:token].presence || cookies.signed[key].presence
        token ||= SecureRandom.uuid
        cookies.signed[key] = {value: token, httponly: true} unless cookies.signed[key] == token
        @resolved_wizard_token = token
      end

      # --- authorization ---

      # Entry auth (§5.2 / §6.5). A wizard may define `authorize?` (default allow);
      # false → 403 via the existing ActionPolicy::Unauthorized rescue. Resource-
      # attached wizards additionally go through the action policy (gated by the
      # synthesized action, mirroring interactive actions).
      def authorize_wizard_entry!(runner)
        wizard = runner.wizard
        return unless wizard.respond_to?(:authorize?)
        return if wizard.authorize?

        raise ActionPolicy::Unauthorized.new(wizard.class, :authorize?)
      end

      # --- params ---

      def wizard_params
        raw = params[:wizard]
        return {} if raw.blank?

        raw.to_unsafe_h.stringify_keys
      end

      # --- URL helpers ---

      # Build the GET URL for a given step of this wizard, preserving the anchor
      # `:id` and `:token` segments. Derived from the current request path by
      # swapping the trailing `:step` segment — robust across the named-route
      # helper without needing it threaded into the controller.
      def wizard_step_url(step_key)
        step = step_key.to_s
        current = params[:step].to_s
        path = request.path
        base = current.present? ? path.delete_suffix("/#{current}") : path
        "#{base}/#{step}"
      end

      def wizard_redirect_step = nil

      # Where a completed wizard redirects (§6). Prefer the outcome value's resource
      # URL; fall back to the portal root.
      def wizard_completion_url(value)
        if value.is_a?(ActiveRecord::Base)
          resource_url_for(value)
        else
          main_or_portal_root_url
        end
      rescue
        main_or_portal_root_url
      end

      # Where Cancel redirects out to.
      def wizard_exit_url
        main_or_portal_root_url
      end

      def main_or_portal_root_url
        current_engine.routes.url_helpers.root_path
      rescue
        "/"
      end
    end
  end
end

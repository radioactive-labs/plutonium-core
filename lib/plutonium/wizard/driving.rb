# frozen_string_literal: true

module Plutonium
  module Wizard
    # Surface-agnostic runner-driving logic shared by every wizard launch surface
    # (§6). It is mixed into:
    #
    # - {Plutonium::Wizard::Controller} — the standalone portal-level
    #   `register_wizard` controller (non-anchored), and
    # - {Plutonium::Resource::Controllers::WizardActions} — the resource-mounted
    #   member/collection actions (anchored anchor comes from the scoped, policy-
    #   gated `resource_record!`, exactly like interactive record actions).
    #
    # Both surfaces share the per-request flow: resolve the instance (URL token /
    # anchor + `current_user` owner + portal `scoped_entity` scope) → build the
    # {Runner} → check entry authorization → GET renders the current step / POST
    # dispatches on `params[:_direction]` (`back` / `cancel` / advance+finalize).
    #
    # Surfaces differ only in a small set of hooks (the wizard class, the anchor,
    # the per-step URL, completion/exit targets, and authorization), which the
    # including controller overrides.
    module Driving
      extend ActiveSupport::Concern
      include Plutonium::StructuredInputs::ParamsConcern

      # Signed-cookie key holding the per-(wizard) token for non-anchored flows.
      def self.token_cookie_key(wizard_class)
        :"pu_wizard_#{wizard_class.name.underscore.tr("/", "_")}"
      end

      private

      # GET .../:step — render the current step (or bounce on a completeness gap).
      def wizard_show
        runner = build_wizard_runner
        authorize_wizard_entry!(runner)

        if (target = wizard_redirect_step)
          return redirect_to wizard_step_url(target), status: :see_other, allow_other_host: false
        end

        # Honor a direct GET to a specific (visited/visible) step — stepper jumps
        # and resume-by-URL. Forward jumps to unvisited steps are ignored.
        runner.go_to(params[:step])

        @wizard_runner = runner
        render_wizard_step(runner)
      end

      # POST .../:step — advance / back / cancel.
      def wizard_update
        runner = build_wizard_runner
        authorize_wizard_entry!(runner)
        @wizard_runner = runner

        if params[:pre_submit]
          return render_wizard_pre_submit(runner)
        end

        result =
          case params[:_direction].to_s
          when "back"
            runner.back
          when "cancel"
            runner.cancel
            return redirect_to wizard_exit_url, status: :see_other, allow_other_host: false
          else
            advance_or_finalize(runner)
          end

        respond_to_wizard_result(runner, result)
      end

      # Advance the current step; if the POSTed step is the last visible step,
      # finalize. The last visible step is the terminal `review` (no fields), so
      # finalize runs directly; otherwise validate + stage + move the cursor.
      def advance_or_finalize(runner)
        return runner.finalize if wizard_posting_last_step?(runner)

        runner.advance(params[:step], wizard_params(runner))
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
          return redirect_to wizard_step_url(target), status: :see_other, allow_other_host: false
        end

        if result.ok?
          redirect_to wizard_step_url(runner.current_step&.key), status: :see_other, allow_other_host: false
        else
          @wizard_errors = result.errors
          render_wizard_step(runner, status: :unprocessable_content)
        end
      end

      # PRG out of a completed wizard: clear the signed token cookie and redirect.
      # A gate (§9 {Plutonium::Wizard::Gate}) may have stashed the user's intended
      # destination in `session[:return_to]` before bouncing them into a one-time
      # wizard; prefer that bounce target over the outcome value's URL.
      def complete_wizard!(result)
        cookies.delete(Plutonium::Wizard::Driving.token_cookie_key(current_wizard_class))
        target = session.delete(:return_to).presence || wizard_completion_url(result.value)
        redirect_to target, status: :see_other, allow_other_host: false
      end

      # --- rendering ---

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

      # A `change->form#preSubmit` re-render: in a turbo frame (modal), replace just
      # the step form; otherwise re-render the whole page. Mirrors interactive
      # actions, where conditional inputs depend on sibling values.
      def render_wizard_pre_submit(runner)
        form = wizard_step_form(runner)
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              helpers.turbo_scoped_dom_id("wizard-form"),
              view_context.render(form)
            )
          end
          format.html { render_wizard_step(runner, status: :unprocessable_content) }
        end
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

      def resolved_wizard_instance_key
        Plutonium::Wizard::InstanceKey.for(
          wizard: current_wizard_class.name,
          scope: resolved_wizard_scope,
          anchor: resolved_wizard_anchor,
          token: resolved_wizard_token,
          owner: current_user
        )
      end

      # The portal scoping entity (tenant) when the portal is entity-scoped (§4 /
      # §8 multi-tenancy); nil otherwise.
      def resolved_wizard_scope
        return unless scoped_to_entity?

        current_scoped_entity
      end

      # The identity principal for non-anchored / pre-auth flows (§4).
      #
      # When there is a `current_user`, we mint **no** token: the principal falls
      # back to the owner GID, giving the documented default of a **singleton per
      # (user, wizard)** — two tabs/devices resume the SAME draft (§4). Tokened
      # concurrent drafts are a deliberate future opt-in, not the default.
      #
      # When there is no `current_user` (pre-auth onboarding/signup), a token in a
      # signed cookie is the only stable principal, so we read/mint one. The cookie
      # is cleared on completion.
      def resolved_wizard_token
        return @resolved_wizard_token if defined?(@resolved_wizard_token)

        @resolved_wizard_token =
          if current_user
            nil
          else
            key = Plutonium::Wizard::Driving.token_cookie_key(current_wizard_class)
            token = params[:token].presence || cookies.signed[key].presence
            token ||= SecureRandom.uuid
            cookies.signed[key] = {value: token, httponly: true} unless cookies.signed[key] == token
            token
          end
      end

      # --- authorization ---

      # Entry auth (§5.2 / §6.5). A wizard may define `authorize?` (default allow);
      # false → 403 via the existing ActionPolicy::Unauthorized rescue. Resource-
      # attached surfaces additionally gate via the action policy (see
      # {WizardActions}); this base check covers the wizard-level hook common to
      # both surfaces.
      def authorize_wizard_entry!(runner)
        wizard = runner.wizard
        return unless wizard.respond_to?(:authorize?)
        return if wizard.authorize?

        raise ActionPolicy::Unauthorized.new(wizard.class, :authorize?)
      end

      # --- params ---

      # Extract the current step's submitted params through the step form (like
      # interactions), so typed inputs and structured/repeater inputs are parsed
      # consistently with how they were rendered — then clean structured inputs
      # (drop blank/template rows) and stringify keys for the data snapshot.
      def wizard_params(runner)
        return {} if params[:wizard].blank?

        step = runner.current_step
        form = wizard_step_form(runner)
        extracted = form.extract_input(params, view_context:)[:wizard] || {}
        cleaned = clean_structured_inputs(Plutonium::Wizard::StepAdapter.new(step), extracted.dup)
        cleaned.stringify_keys
      end

      # The form for the current step, seeded from the wizard's typed data — used
      # for both param extraction and the pre_submit turbo re-render.
      def wizard_step_form(runner)
        step = runner.current_step
        Plutonium::UI::Form::Wizard.new(
          step:,
          data: runner.wizard.data,
          action: wizard_step_url(step&.key),
          fields: step.attribute_schema.keys.map(&:to_sym) + step.structured_inputs.keys.map(&:to_sym)
        )
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

      # --- surface hooks (overridden per surface) ---

      # @return [Class] the wizard class for this request.
      def current_wizard_class
        raise NotImplementedError
      end

      # @return [ActiveRecord::Base, nil] the anchor record (scoped/authorized for
      #   resource-mounted member actions; nil for non-anchored surfaces).
      def resolved_wizard_anchor
        nil
      end

      # @return [String] the GET URL for a given step of this wizard.
      def wizard_step_url(step_key)
        raise NotImplementedError
      end
    end
  end
end

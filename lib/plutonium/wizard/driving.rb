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

      # How long the per-run id cookie lives. Short by design — it only needs to
      # outlast an in-progress run, and a guest run's data hangs off it (§4.5).
      TOKEN_COOKIE_TTL = 1.day

      # Signed-cookie key holding the per-(wizard) run id for non-keyed flows.
      def self.token_cookie_key(wizard_class)
        :"pu_wizard_#{wizard_class.name.underscore.tr("/", "_")}"
      end

      private

      # GET .../:step — render the current step (or bounce on a completeness gap).
      def wizard_show
        require_wizard_authentication!
        runner = build_wizard_runner
        deny_wizard_resume_for_other_user!(runner)
        authorize_wizard_entry!(runner)

        # Re-entering a finished one-time wizard (§4.3/§9): its key holds a
        # retained `completed` row, so there is nothing to run — bounce out.
        if runner.completed_one_time?
          return redirect_to wizard_exit_url, status: :see_other, allow_other_host: false
        end

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
        require_wizard_authentication!
        runner = build_wizard_runner
        deny_wizard_resume_for_other_user!(runner)
        authorize_wizard_entry!(runner)
        @wizard_runner = runner

        if runner.completed_one_time?
          return redirect_to wizard_exit_url, status: :see_other, allow_other_host: false
        end

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
          owner: resolved_wizard_owner,
          anchor: resolved_wizard_anchor,
          scope: resolved_wizard_scope,
          token: wizard_token,
          current_user: resolved_wizard_owner,
          current_scoped_entity: resolved_wizard_scope
        )
      end

      # The authenticated user driving this run, or nil for a guest (`anonymous`)
      # run (§4.5). The public surface stubs `current_user` to the "Guest"
      # sentinel; a guest run has NO owner — its identity is the unguessable
      # `wizard_token`, not a principal. Normalizing to nil keeps the runner's
      # owner-scoping and the wizard's `current_user` honest.
      def resolved_wizard_owner
        return nil if current_wizard_class.anonymous?

        current_user_present_for_wizard? ? current_user : nil
      end

      def wizard_store
        Plutonium::Wizard::Store::ActiveRecord.new
      end

      # The instance_key for this run (§4.1). A wizard with a `concurrency_key`
      # gets a stable digest over its resolved key value(s) (tenant folded in);
      # otherwise the digest is over the per-launch `wizard_token` (fresh per
      # launch → repeatable). This MUST stay byte-identical to the gate's
      # recomputation (§9), so both go through {InstanceKey}.
      def resolved_wizard_instance_key
        Plutonium::Wizard.compute_instance_key(
          wizard_class: current_wizard_class,
          current_user: resolved_wizard_owner,
          current_scoped_entity: resolved_wizard_scope,
          anchor: resolved_wizard_anchor,
          wizard_token: wizard_token
        )
      end

      # The portal scoping entity (tenant) when the portal is entity-scoped (§4.4 /
      # §8 multi-tenancy); nil otherwise. Folded into the key automatically.
      def resolved_wizard_scope
        return unless scoped_to_entity?

        current_scoped_entity
      end

      # The per-run id (§4.5): URL `:token` param ?? signed cookie, server-minted
      # and set if absent. It is the identity principal for runs without a
      # `concurrency_key` — guest (`anonymous`) runs AND authenticated repeatable
      # runs — and is folded into `concurrency_key` resolution. It is NOT a
      # pre-auth principal that survives login: authenticated runs are guarded by
      # owner-scoping, and the wizard never crosses the auth boundary mid-flow.
      #
      # The token is unguessable (`SecureRandom.uuid`). The cookie is the only
      # thing protecting an in-progress GUEST run's data, so it is hardened:
      # httponly, secure, same_site :lax, short-lived; it is cleared on completion.
      def wizard_token
        return @wizard_token if defined?(@wizard_token)

        key = Plutonium::Wizard::Driving.token_cookie_key(current_wizard_class)
        token = params[:token].presence || cookies.signed[key].presence
        token ||= SecureRandom.uuid
        unless cookies.signed[key] == token
          cookies.signed[key] = {
            value: token,
            httponly: true,
            secure: wizard_cookie_secure?,
            same_site: :lax,
            expires: Plutonium::Wizard::Driving::TOKEN_COOKIE_TTL.from_now
          }
        end
        @wizard_token = token
      end

      # `secure: true` everywhere except when the request itself isn't over TLS
      # (local HTTP dev/test) — a `secure` cookie is dropped by the browser on
      # plain HTTP, which would silently break the dev/test flow.
      def wizard_cookie_secure?
        request.ssl? || Rails.env.production?
      end

      # --- authorization ---

      # Authentication gate (§4.5). Wizards REQUIRE authentication by default —
      # entry without a `current_user` is rejected. An `anonymous` wizard opts out
      # (guest access; it may authenticate only at its terminal `execute`).
      #
      # When a `current_user` is missing for a non-`anonymous` wizard we reject the
      # way the host already handles unauthenticated access: Rodauth's
      # `require_authentication` (redirect to login) when the portal exposes it,
      # else a plain 401. We deliberately do NOT lean on the portal's own auth
      # before_action because the public mount (for `anonymous` wizards) runs
      # OUTSIDE the portal's authenticated route constraint.
      def require_wizard_authentication!
        return if current_wizard_class.anonymous?
        return if current_user_present_for_wizard?

        if respond_to?(:rodauth, true)
          rodauth.require_authentication
        else
          head :unauthorized
        end
      end

      # `current_user` is truthy AND not the {Plutonium::Auth::Public} "Guest"
      # sentinel (a public controller stubs `current_user` to the string "Guest").
      def current_user_present_for_wizard?
        user = current_user
        user.present? && user != "Guest"
      end

      # Owner-scoped resume (§4.5): a non-`anonymous` wizard's row may only be
      # resumed by its owner. The runner flags a mismatched row as forbidden; we
      # 404 (rather than fork a fresh run) so a run id leaked in a URL can't be
      # picked up by — or even probed by — another logged-in user.
      def deny_wizard_resume_for_other_user!(runner)
        return unless runner.forbidden?

        raise ActiveRecord::RecordNotFound, "wizard run not found"
      end

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

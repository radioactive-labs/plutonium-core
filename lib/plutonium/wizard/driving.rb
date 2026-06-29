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

      # The Rails-session bucket holding per-wizard guest run ids (§4.5). A guest
      # (`anonymous`) run's token lives under `session[SESSION_TOKENS_KEY][wizard_key]`.
      SESSION_TOKENS_KEY = "plutonium_wizards"

      # The Rails-session bucket holding the per-wizard "return to" path captured at
      # launch — the page the user came from. Cancel redirects there instead of the
      # host root. Namespaced per wizard so two in-flight wizards don't clobber each
      # other.
      WIZARD_RETURN_TO_KEY = "plutonium_wizard_return_to"

      # The per-wizard key under {SESSION_TOKENS_KEY} for a guest run's token.
      def self.session_token_key(wizard_class)
        wizard_class.name.underscore.tr("/", "_")
      end

      private

      # GET the bare mount (no :step) — the canonical launch. Resolve the run (mint
      # the per-run token for a tokened wizard, or resolve the keyed/guest identity),
      # then PRG to its entry step — the resumed cursor for an in-progress keyed/guest
      # run, else the first visible step. The redirect URL carries the token, so the
      # address bar shows a stable, shareable run URL from the first paint (no more
      # "token appears only after the first submit", and no fork-on-reload).
      def wizard_launch
        require_wizard_authentication!
        stash_wizard_return_to!

        # `on_relaunch :prompt` (§4.5): when the user already has pending runs of
        # this (tokened) wizard, show a "resume or start new" chooser instead of
        # forking a fresh run. Decided BEFORE `build_wizard_runner`, which would
        # otherwise mint a token.
        if wizard_relaunch_prompt?
          return render_wizard_chooser
        end

        runner = build_wizard_runner
        deny_wizard_resume_for_other_user!(runner)
        authorize_wizard_entry!(runner)

        if runner.completed_one_time?
          return render_wizard_completed(runner)
        end

        redirect_to wizard_step_url(runner.current_step&.key), status: :see_other, allow_other_host: false
      end

      # Whether the bare launch should divert to the resume-or-new chooser: the
      # wizard opted in (`on_relaunch :prompt`), it's an authenticated TOKENED run
      # (keyed wizards already auto-resume; `anonymous` runs are session-keyed),
      # the request isn't the explicit "start new" path, and a pending run exists.
      def wizard_relaunch_prompt?
        klass = current_wizard_class
        return false unless klass.relaunch_prompt?
        return false if klass.anonymous? || klass.concurrency_key?
        return false if params[:new].present?

        wizard_pending_entries.any?
      end

      # This wizard's in-progress runs for the current owner (tenant-scoped),
      # enriched with resume URLs — via the shared {Resume} listing module. The
      # `wizard:` filter narrows in the query, so only THIS wizard's rows are
      # enriched (not every pending run of every wizard, then discarded).
      def wizard_pending_entries
        @wizard_pending_entries ||=
          Plutonium::Wizard::Resume.entries_for(view_context, wizard: current_wizard_class)
      end

      # GET .../:step — render the current step (or bounce on a completeness gap).
      def wizard_show
        require_wizard_authentication!
        runner = build_wizard_runner
        deny_wizard_resume_for_other_user!(runner)
        authorize_wizard_entry!(runner)

        # Re-entering a finished one-time wizard (§4.3/§9): its key holds a
        # retained `completed` row whose `data` was cleared on completion, so there
        # is nothing to review — render the standalone "already completed" page.
        if runner.completed_one_time?
          return render_wizard_completed(runner)
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

        # A POST to a finished one-time wizard (stale form / double submit): nothing
        # to run. PRG to the step URL so the follow-up GET renders the completed page.
        if runner.completed_one_time?
          return redirect_to wizard_step_url(runner.current_step&.key), status: :see_other, allow_other_host: false
        end

        # Align the in-memory cursor to the step being POSTed. A user can navigate
        # BACK to an earlier step via a GET (stepper jump / direct URL), which by
        # design does NOT persist the cursor — so the stored cursor still points at
        # a LATER step. Without realigning, `wizard_params`/`wizard_step_form` would
        # extract this submission through the wrong step's form: the edited fields
        # are silently dropped and the stored-cursor step's fields leak in. The step
        # carried in the URL is the one being submitted, so make it current.
        #
        # `go_to` returns false when that step is NOT reachable for this run — a
        # branch-hidden step, or a forward jump to an unvisited step. A forged or
        # stale POST to such a step must be REFUSED here: otherwise `advance` would
        # look the step up across the whole declaration list and validate/stage/run
        # its `on_submit` for a step the user can't see (the branch-prune only
        # compensates `persist`ed records, never raw side effects). PRG back to the
        # run's actual current step instead of processing the submission.
        unless runner.go_to(params[:step])
          return redirect_to wizard_step_url(runner.current_step&.key), status: :see_other, allow_other_host: false
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
            target = wizard_exit_url
            clear_wizard_return_to
            return redirect_to target, status: :see_other, allow_other_host: false
          else
            advance_or_finalize(runner)
          end

        respond_to_wizard_result(runner, result)
      end
 
      # DELETE (/:token) — cancel run.
      def wizard_cancel
        require_wizard_authentication!
        runner = build_wizard_runner
        deny_wizard_resume_for_other_user!(runner)
        authorize_wizard_entry!(runner)
 
        runner.cancel
        clear_wizard_session_token
 
        # PRG back to the bare launch path (or return_to), which will reload the chooser or start a new run.
        # But we'll redirect back to the launch url of the wizard.
        target = wizard_launch_url
        redirect_to target, status: :see_other, allow_other_host: false
      end

      # Advance the current step; if the POSTed step is the last visible step,
      # finalize. The last visible step is the terminal `review` (no fields), so
      # finalize runs directly; otherwise validate + stage + move the cursor.
      def advance_or_finalize(runner)
        return runner.finalize if wizard_posting_last_step?(runner)

        runner.advance(params[:step], wizard_params(runner), goto: params[:_goto].presence)
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

      # PRG out of a completed wizard: clear the guest run's session token and
      # redirect. A gate (§9 {Plutonium::Wizard::Gate}) may have stashed the user's
      # intended destination in `session[:return_to]` before bouncing them into a
      # one-time wizard; prefer that bounce target over the outcome value's URL.
      def complete_wizard!(result)
        clear_wizard_session_token
        # Completion lands on the RESULT (the created/updated resource) by default,
        # not the launch origin — so drop the captured return-to. A gate's stashed
        # `:return_to` (the page the user was bounced FROM into a one-time wizard)
        # still wins, so they resume where they were headed.
        clear_wizard_return_to
        if result.respond_to?(:messages)
          result.messages.each do |message, type|
            flash[type] = message
          end
        end
        target = session.delete(:return_to).presence || wizard_completion_url(result.value)
        redirect_to target, status: :see_other, allow_other_host: false
      end

      # Drop a guest run's token from the Rails session (on completion). A no-op
      # for authenticated runs, whose token rides the URL, not the session.
      def clear_wizard_session_token
        bucket = session[Plutonium::Wizard::Driving::SESSION_TOKENS_KEY]
        return unless bucket.is_a?(Hash)

        bucket.delete(Plutonium::Wizard::Driving.session_token_key(current_wizard_class))
        session.delete(Plutonium::Wizard::Driving::SESSION_TOKENS_KEY) if bucket.empty?
      end

      # --- rendering ---

      # The "resume or start new" chooser (§4.5), rendered at the bare launch URL
      # when `on_relaunch :prompt` and pending runs exist. "Start new" re-enters
      # this launch with `?new=1`, which skips the chooser and mints a fresh run.
      def render_wizard_chooser
        render(
          Plutonium::UI::Page::WizardChooser.new(
            wizard_class: current_wizard_class,
            entries: wizard_pending_entries,
            start_new_url: "#{request.path}?new=1"
          ),
          **wizard_modal_render_options
        )
      end

      # The standalone "already completed" page for a re-opened one-time wizard
      # (§9). Its `data` was cleared on completion, so this never shows the review —
      # just a confirmation (or the wizard's `completed` block).
      def render_wizard_completed(runner)
        render(
          Plutonium::UI::Page::WizardCompleted.new(
            runner:,
            exit_url: wizard_exit_url
          ),
          **wizard_modal_render_options
        )
      end

      def render_wizard_step(runner, status: :ok)
        render(
          Plutonium::UI::Page::Wizard.new(
            runner:,
            step_url: wizard_step_url(runner.current_step&.key),
            errors: @wizard_errors,
            description: wizard_page_description
          ),
          status:,
          **wizard_modal_render_options
        )
      end

      # A `change->form#preSubmit` re-render: in a turbo frame (modal), replace just
      # the step form; otherwise re-render the whole page. Mirrors interactive
      # actions, where conditional inputs depend on sibling values.
      def render_wizard_pre_submit(runner)
        runner.stage_inputs(runner.current_step.key, wizard_extracted_inputs(runner).stringify_keys)

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

      def wizard_page_description = nil

      # The render options (chiefly the layout) for a wizard page:
      # - turbo-frame request → no layout (the embedded/modal case);
      # - a resolved layout NAME → render in it (e.g. `basic` for an onboarding
      #   screen);
      # - nil → inherit the controller's layout (the resource shell), so a custom
      #   controller layout still wins.
      def wizard_modal_render_options
        return {layout: false} if helpers.current_turbo_frame.present?

        layout = wizard_layout
        layout ? {layout:} : {}
      end

      # The Rails layout this run renders in — a layout NAME, exactly like the
      # controller `layout` macro: `basic` (the bare BasicLayout, e.g. onboarding),
      # `resource` (the standard shell), or any app layout. An explicit `layout:`
      # from `register_wizard` rides as a route DEFAULT — one synthesized controller
      # serves many mounts, so the per-mount value travels on the route, not the
      # controller. Absent, it defaults by host: main-app → `"basic"` (no shell to
      # embed in), portal → nil (inherit the controller's resource shell). Resource-
      # defined wizards carry no `layout:` and render embedded (turbo frame → no
      # layout, above).
      def wizard_layout
        explicit = params[:wizard_layout]
        return explicit if explicit.present?

        (current_engine == Rails.application.class) ? "basic" : nil
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
          # The portal this run is launched in — recorded so the resume listing
          # only ever surfaces it from THIS portal (§4.5).
          engine: current_engine.name,
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

      # The per-run id (§4.5). It is the identity principal for runs without a
      # `concurrency_key` — guest (`anonymous`) runs AND authenticated repeatable
      # runs — and is folded into `concurrency_key` resolution. It is NOT a
      # pre-auth principal that survives login: authenticated runs are guarded by
      # owner-scoping, and the wizard never crosses the auth boundary mid-flow.
      #
      # Two sources, by run identity:
      #
      # - **Guest (`anonymous`) runs** key off the **Rails session**, namespaced
      #   per wizard (`session["plutonium_wizards"][<wizard_key>]`), minted with
      #   `SecureRandom.alphanumeric(32)` and stored if absent, read each request. We never
      #   read the token from the URL for a guest run — the session is the only
      #   source, so there is no URL-leak surface. There is no TTL: the row's
      #   `cleanup_after` → sweep is the authoritative lifetime; the session token
      #   is just a pointer (browser-close ephemeral, auto-cleared by Rodauth's
      #   `reset_session` on login/logout, and cleared on completion).
      # - **Authenticated repeatable runs** carry their per-run id in the URL
      #   `:token` segment (owner-scoped on the row), minting one when absent so a
      #   fresh launch is a fresh run.
      def wizard_token
        return @wizard_token if defined?(@wizard_token)

        @wizard_token =
          if current_wizard_class.anonymous?
            guest_session_token
          else
            params[:token].presence || SecureRandom.alphanumeric(32)
          end
      end

      # Read (minting + storing if absent) the guest run's token from the Rails
      # session bucket. Session storage gives browser-close ephemerality and
      # auto-clear on login/logout (Rodauth's `clear_session` → `reset_session`).
      def guest_session_token
        bucket = (session[Plutonium::Wizard::Driving::SESSION_TOKENS_KEY] ||= {})
        key = Plutonium::Wizard::Driving.session_token_key(current_wizard_class)
        bucket[key] ||= SecureRandom.alphanumeric(32)
      end

      # The token to thread into a step URL, if any. An authenticated REPEATABLE
      # run (no `concurrency_key` → tokened identity) carries its per-run id in the
      # URL `:token` segment, so a fresh GET resumes rather than forks. A guest
      # (`anonymous`) run keys off the Rails session, so its token MUST NOT appear
      # in the URL (no leak surface); a keyed run's identity is its
      # `concurrency_key`, so the token is irrelevant there. `nil` keeps it off.
      def wizard_url_token
        return nil if current_wizard_class.anonymous?
        return nil if current_wizard_class.concurrency_key?

        wizard_token
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

        cleaned = wizard_extracted_inputs(runner)
        stage_wizard_uploads!(runner.current_step, cleaned)
        cleaned.stringify_keys
      end

      # Like {#wizard_params} but WITHOUT staging uploads — shared with the
      # `pre_submit` re-render, which must not stage them, or every `change` event
      # would push the selected file to the backend cache.
      def wizard_extracted_inputs(runner)
        return {} if params[:wizard].blank?

        step = runner.current_step
        form = wizard_step_form(runner)
        extracted = form.extract_input(params, view_context:)[:wizard] || {}
        clean_structured_inputs(Plutonium::Wizard::StepAdapter.new(step), extracted.dup)
      end

      # Replace each attachment field's value with a staged TOKEN, minting one from
      # an uploaded file for a plain (non-direct-upload) field. Reads the RAW param
      # so a multipart `UploadedFile` isn't mangled by form extraction, then
      # overrides the extracted value. A nil result (blank / no new file) drops the
      # key, so the token already in `data` survives a Back/re-submit (`stage`
      # merges, it doesn't replace). Direct-upload fields arrive as a token string
      # and pass through unchanged.
      def stage_wizard_uploads!(step, cleaned)
        raw = params[:wizard]
        step.inputs.each do |name, config|
          next unless Plutonium::Wizard::Attachments.field?(config)

          token = Plutonium::Wizard::Attachments.stage_upload(
            raw[name], backend: config.dig(:options, :backend)
          )
          if token.nil?
            cleaned.delete(name)
            cleaned.delete(name.to_s)
          else
            cleaned[name] = token
          end
        end
      end

      # The form for the current step, seeded from the wizard's typed data — used
      # for both param extraction and the pre_submit turbo re-render.
      def wizard_step_form(runner)
        step = runner.current_step
        Plutonium::UI::Form::Wizard.new(
          step:,
          data: Plutonium::Wizard::AttachmentData.wrap(runner.wizard.data[step.key], step),
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

      # Where Cancel redirects out to: the page the user launched from (captured at
      # launch), falling back to the host root.
      def wizard_exit_url
        peek_wizard_return_to || main_or_portal_root_url
      end

      # Capture the launch origin so Cancel can return there. Called only at the bare
      # launch (the step pages' referer is the wizard itself). Prefers an explicit
      # `?return_to=` over the referer; both are sanitized to a same-host local path
      # that isn't the wizard's own mount, so there's no open-redirect surface.
      def stash_wizard_return_to!
        candidate = wizard_return_to_candidate
        return if candidate.blank?

        bucket = (session[WIZARD_RETURN_TO_KEY] ||= {})
        bucket[Plutonium::Wizard::Driving.session_token_key(current_wizard_class)] = candidate
      end

      def wizard_return_to_candidate
        [params[:return_to].to_s, request.referer].each do |raw|
          path = local_wizard_return_path(raw)
          return path if path
        end
        nil
      end

      # Sanitize a candidate return-to into a same-host absolute path (with query),
      # or nil. Rejects other hosts (open-redirect), protocol-relative `//host`
      # paths, and the wizard's own pages (so Cancel never bounces back into the
      # flow it's leaving).
      def local_wizard_return_path(raw)
        return nil if raw.blank?

        uri = begin
          URI.parse(raw)
        rescue URI::InvalidURIError
          nil
        end
        return nil if uri.nil?
        return nil unless uri.host.nil? || uri.host == request.host

        path = uri.path.presence
        return nil if path.nil? || !path.start_with?("/") || path.start_with?("//")
        return nil if path.start_with?(request.path)

        uri.query.present? ? "#{path}?#{uri.query}" : path
      end

      def peek_wizard_return_to
        bucket = session[WIZARD_RETURN_TO_KEY]
        return nil unless bucket.is_a?(Hash)

        bucket[Plutonium::Wizard::Driving.session_token_key(current_wizard_class)].presence
      end

      def clear_wizard_return_to
        bucket = session[WIZARD_RETURN_TO_KEY]
        return unless bucket.is_a?(Hash)

        bucket.delete(Plutonium::Wizard::Driving.session_token_key(current_wizard_class))
        session.delete(WIZARD_RETURN_TO_KEY) if bucket.empty?
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
 
      # @return [String] the GET URL for launching this wizard.
      def wizard_launch_url
        raise NotImplementedError
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Drives the portal-hosted wizard controller + register_wizard routing end to end
# through the admin portal (non-entity-scoped). Mirrors the interactive-action
# integration tests for request shape and login, and exercises the real step-form
# UI (Task 6): typed inputs, the stepper, `using:` imports, repeater rehydration
# on GET, and the review auto-summary with a gated finish.
class AdminPortal::WizardFlowTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    Plutonium::Wizard::Session.delete_all
  end

  def base = "/admin/onboarding"

  # Advance the linear flow up to (but not including) the named step, staging
  # valid data for each step in between. OnboardOrganizationWizard is tokened
  # (no concurrency_key), so for an authenticated run the per-run id rides the URL
  # `:token` segment — thread it through each POST so steps stay on one run
  # (instead of forking a fresh tokened run per request).
  def advance_through(*steps)
    payloads = {
      "identity" => {name: "Acme Inc", plan: "pro", budget: "1500.50"},
      "details" => {note: "hello"},
      "profile" => {description: "a great org", tier: "1"},
      "members" => {invites: [{email: "a@example.com", role: "admin"}]}
    }
    steps.each do |step|
      step_base = @wizard_token ? "#{base}/#{@wizard_token}" : base
      post "#{step_base}/#{step}", params: {wizard: payloads.fetch(step), _direction: "next"}
      follow_redirect!
      @wizard_token ||= Plutonium::Wizard::Session.where(status: "in_progress").first&.token
    end
  end

  # The base URL for the run started by `advance_through`, carrying the per-run
  # token so a subsequent direct request stays on that run (not a fresh fork).
  def tbase = @wizard_token ? "#{base}/#{@wizard_token}" : base

  test "GET the bare mount launches: redirects to the first step with a token" do
    get base
    assert_response :redirect
    # Tokened wizard (no concurrency_key) → the redirect carries a freshly-minted
    # :token segment, landing on the first step. No fork-on-reload: the token is in
    # the URL from here on.
    assert_match %r{\A#{Regexp.escape(base)}/[A-Za-z0-9]{32}/identity\z}, URI(response.location).path
  end

  # --- relaunch chooser (default `on_relaunch :prompt`) ----------------------

  # OnboardOrganizationWizard is tokened and relies on the default `on_relaunch
  # :prompt`: a bare launch with NO pending runs still mints a fresh run (unchanged).
  test "bare launch with no pending runs starts fresh" do
    assert_equal 0, Plutonium::Wizard::Session.where(status: "in_progress").count
    get base
    assert_response :redirect
    assert_match %r{\A#{Regexp.escape(base)}/[A-Za-z0-9]{32}/identity\z}, URI(response.location).path
  end

  # With a pending run, the bare launch shows the resume-or-new chooser instead of
  # forking — listing the pending run with a Resume link (carrying its token) and a
  # Start-new control.
  test "bare launch with a pending run shows the resume-or-new chooser" do
    advance_through("identity") # one in-progress run owned by the admin (now on details)
    get base
    assert_response :success
    assert_includes response.body, "pu-wizard-chooser"
    assert_match %r{href="#{Regexp.escape(base)}/#{@wizard_token}/details"[^>]*data-wizard-chooser-resume}, response.body
    assert_match %r{data-wizard-chooser-start-new}, response.body
    assert_includes response.body, "?new=1"
  end

  # The Start-new path (`?new=1`) bypasses the chooser and mints a fresh run, even
  # when a pending one exists. No new row yet (token minted; row created on first submit).
  test "bare launch with ?new=1 starts fresh despite a pending run" do
    advance_through("identity")
    before = Plutonium::Wizard::Session.where(status: "in_progress").count
    get "#{base}?new=1"
    assert_response :redirect
    assert_match %r{\A#{Regexp.escape(base)}/[A-Za-z0-9]{32}/identity\z}, URI(response.location).path
    assert_equal before, Plutonium::Wizard::Session.where(status: "in_progress").count
  end

  test "GET first step renders the step form fields" do
    get "#{base}/identity"
    assert_response :success
    assert_includes response.body, %(name="wizard[name]")
    assert_includes response.body, %(name="_direction")
    # A portal `register_wizard` mount defaults to the in-shell chrome.
    assert_includes response.body, "sidebar-navigation",
      "a portal standalone wizard defaults to the in-shell layout"
    assert_includes response.body, "Set up a workspace for your team",
      "the wizard's presents description renders in the page header"
  end

  # A step's inline `validates ... presence: true` is replayed onto the typed
  # data class, so the shared form pipeline surfaces the required marker — same
  # as a resource form. `name` is required; `plan` is not.
  test "required step fields render the required marker" do
    get "#{base}/identity"
    assert_response :success

    name_label = response.body[/<label[^>]*for="wizard_name"[^>]*>.*?<\/label>/m]
    plan_label = response.body[/<label[^>]*for="wizard_plan"[^>]*>.*?<\/label>/m]

    assert_match(/<abbr[^>]*title="required"/, name_label, "expected required marker on the validated `name` field")
    refute_match(/<abbr[^>]*title="required"/, plan_label, "did not expect a required marker on the unvalidated `plan` field")
  end

  # --- typed inputs (not plain text) -----------------------------------------

  test "the step form renders real typed inputs, not plain text" do
    get "#{base}/identity"
    assert_response :success
    # plan declared `as: :select` → a <select>, not a text input.
    assert_match(/<select[^>]*name="wizard\[plan\]"/, response.body)
    # inline form_layout section heading renders.
    assert_includes response.body, "The basics"
  end

  test "a textarea input renders as a textarea" do
    advance_through("identity")
    # now on details
    assert_match(/<textarea[^>]*name="wizard\[note\]"/, response.body)
    assert_includes response.body, "textarea-autogrow"
  end

  # --- using: imported fields render with their styling ----------------------

  test "a using: step renders imported fields with their input styling" do
    advance_through("identity", "details")
    # now on profile (imports KitchenSink :description + :tier)
    assert_includes response.body, %(name="wizard[description]")
    # tier is `as: :select` in KitchenSinkDefinition → a slim-select <select>.
    assert_match(/<select[^>]*name="wizard\[tier\]"/, response.body)
    assert_includes response.body, "slim-select"
  end

  # --- stepper ----------------------------------------------------------------

  test "the stepper renders step states and links visited steps" do
    get "#{base}/identity"
    assert_response :success
    assert_includes response.body, "pu-wizard-stepper"
    # The current step is marked current; later steps are upcoming.
    assert_includes response.body, %(data-wizard-stepper-state="current")
    assert_includes response.body, %(data-wizard-stepper-state="upcoming")

    # After advancing, the visited step links back; the new current is marked. The
    # link carries the per-run token segment (authenticated tokened run, §4.5) and
    # wraps the step's node + label.
    advance_through("identity")
    assert_match(
      %r{<a href="/admin/onboarding/#{@wizard_token}/identity"[^>]*class="pu-step-link"[^>]*>.*?Identity.*?</a>}m,
      response.body
    )
  end

  # The review step isn't a numbered step (it's the finish line): no "Step N of M"
  # count on its card or a numbered node in the rail — a flag icon instead. Real
  # steps count among themselves (review excluded from the denominator).
  test "review carries no step count; real steps count with review excluded" do
    advance_through("identity") # now on details: step 2 of the 4 real steps
    assert_includes response.body, "Step 2 of 4"

    get "#{tbase}/review"
    assert_response :success
    refute_match(/Step\s+\d+\s+of\s+\d+/i, response.body) # no count on review
    assert_includes response.body, "pu-step-flag"          # rail review node = flag
  end

  # --- repeater rehydration on GET (resume) ----------------------------------

  test "a structured_input repeat: step rehydrates N rows from staged data on GET" do
    advance_through("identity", "details", "profile")
    # now on members — stage two invite rows
    post "#{tbase}/members", params: {
      wizard: {invites: [
        {email: "a@example.com", role: "admin"},
        {email: "b@example.com", role: "member"}
      ]},
      _direction: "next"
    }
    follow_redirect! # advances to review

    # Navigate back to members via a direct GET (stepper jump / resume).
    get "#{tbase}/members"
    assert_response :success
    assert_includes response.body, %(data-controller="nested-resource-form-fields")
    # Both rows render, seeded with their staged values (not just one blank row).
    assert_includes response.body, %(name="wizard[invites][0][email]")
    assert_includes response.body, %(name="wizard[invites][1][email]")
    assert_includes response.body, %(value="a@example.com")
    assert_includes response.body, %(value="b@example.com")
  end

  # --- review: state machine -------------------------------------------------

  # Summary is on by default, so a complete review shows the summary AND the
  # author's custom block BELOW it (the block is additive, not a replacement) —
  # plus the "check everything over" prompt, since the summary is shown.
  test "a complete review shows the summary with the custom block below it" do
    advance_through("identity", "details", "profile", "members")
    # now on review (all steps complete), summary on + custom block
    assert_includes response.body, %(data-wizard-review-step="identity") # summary
    assert_includes response.body, "Acme Inc"
    # `plan` was submitted as "pro"; its select uses [label, value] choices, so
    # the summary must show the resolved label "Pro", not the raw value.
    identity_card = response.body[%r{data-wizard-review-step="identity".*?</section>}m]
    assert_includes identity_card, "Pro",
      "the choice field's summary should show its label, not the raw value"
    # `budget` was submitted as "1500.50" via an `as: :currency` input; the
    # summary must format it as currency, not echo the raw decimal.
    assert_includes identity_card, "$1,500.50",
      "the currency field's summary should render as currency, not a bare decimal"
    assert_includes response.body, "Ready to onboard Acme Inc"           # custom block
    assert_includes response.body, %(data-wizard-review-custom)
    # The custom block sits BELOW the summary.
    assert_operator response.body.index(%(data-wizard-review-step="identity")),
      :<, response.body.index(%(data-wizard-review-custom)),
      "the custom block should render below the summary"
    # The custom body is bare — no tinted "green field" callout around it.
    refute_includes response.body, "bg-primary-50"
    # The check-everything prompt shows because the summary is shown.
    assert_includes response.body, "Check everything over before you finish"
    # Finish is enabled (all steps complete).
    finish_btn = response.body[/<button[^>]*data-wizard-nav="finish"[^>]*>/]
    refute_includes finish_btn, "disabled"
  end

  # The auto-summary is the INCOMPLETE-state (review-and-fix) view: it lists the
  # entered data alongside the outstanding-steps banner.
  test "an incomplete review shows outstanding steps and the entered-data summary" do
    advance_through("identity") # only the first step is complete
    # Jump to review via direct GET — it surfaces outstanding steps + gated finish.
    get "#{tbase}/review"
    assert_response :success
    assert_includes response.body, "wizard-review-outstanding"
    assert_includes response.body, %(data-wizard-review-fix="details")
    # The summary of what's entered so far renders too.
    assert_includes response.body, %(data-wizard-review-step="identity")
    assert_includes response.body, "Acme Inc"
    finish_btn = response.body[/<button[^>]*data-wizard-nav="finish"[^>]*>/]
    assert_includes finish_btn, "disabled"
  end

  test "finalize is blocked while a step is incomplete (bounces, no record)" do
    advance_through("identity")
    assert_no_difference -> { Organization.count } do
      post "#{tbase}/review", params: {_direction: "next"}
    end
    # Bounced to the first incomplete step.
    assert_response :redirect
  end

  # --- full happy path --------------------------------------------------------

  test "full flow: advance through every step then finish creates the record (PRG)" do
    advance_through("identity", "details", "profile", "members")
    assert_includes response.body, "Review"

    assert_difference -> { Organization.count }, 1 do
      post "#{tbase}/review", params: {_direction: "next"}
    end
    assert_response :redirect
    assert Organization.exists?(name: "Acme Inc")
  end

  # A finalize (`execute`) that fails a model validation — e.g. a uniqueness
  # check — must SURFACE the error on the review page, not silently re-render. The
  # error is field-level (name), and review has no field form to attach it to, so
  # it renders as a full message in the review's error banner.
  test "a finalize validation error is surfaced on the review page" do
    Organization.create!(name: "Acme Inc") # the name advance_through stages → duplicate
    advance_through("identity", "details", "profile", "members") # → review, all complete

    assert_no_difference -> { Organization.count } do
      post "#{tbase}/review", params: {_direction: "next"}
    end
    assert_response :unprocessable_content
    assert_match(/has already been taken/i, response.body)
  end

  test "advance with invalid input re-renders with errors and does not advance" do
    post "#{base}/identity", params: {wizard: {name: ""}, _direction: "next"}
    assert_response :unprocessable_content
    # The validation MESSAGE must actually render — not just the field label. (A
    # `data` memo reset between seed_errors! and the form read once swallowed it.)
    assert_match(/can.{0,6}t be blank/i, response.body) # HTML-escaped apostrophe (&#39;)
    assert_equal 0, Organization.count
  end

  test "a validation error keeps the submitted sibling values, not stale ones" do
    # `name` is invalid (blank), but the user also picked a `plan`. The error
    # re-render must KEEP the chosen plan — reverting it (the bug: only success
    # stages data, so an error reverted every field to its last staged value)
    # silently discards correct input the user already entered.
    post "#{base}/identity", params: {wizard: {name: "", plan: "pro"}, _direction: "next"}
    assert_response :unprocessable_content
    assert_match(/<option[^>]*value="pro"[^>]*selected|selected[^>]*value="pro"/, response.body,
      "the plan the user chose survives a sibling field's validation error")
    # The forward button stays "Next" — the errored step wasn't actually submitted
    # (the rejected input is staged in-memory only, which would otherwise flip the
    # label to "Save & continue").
    assert_includes forward_button, "Next"
    refute_includes forward_button, "Save"
  end

  # Regression (§6): navigating BACK to an earlier step via a GET doesn't persist
  # the cursor, so the stored cursor still points at a later step. A subsequent
  # POST to the earlier step must still extract THIS step's fields (not the stored
  # cursor step's) — otherwise the edit is silently dropped and the later step's
  # fields leak into this step's slice.
  test "re-submitting an earlier step after a back-jump stages the edited value" do
    advance_through("identity", "details")
    # Cursor is now on profile. Jump back to identity via a GET (no persist).
    get "#{tbase}/identity"
    assert_response :success
    assert_includes response.body, %(value="Acme Inc")

    # Edit the name and submit the identity step.
    post "#{tbase}/identity", params: {wizard: {name: "Renamed Co", plan: "pro"}, _direction: "next"}
    assert_response :redirect

    # The review summary reflects the edited value — not the stale one.
    get "#{tbase}/review"
    assert_includes response.body, "Renamed Co"
    refute_includes response.body, "Acme Inc"

    # And the identity slice didn't pick up a foreign field (e.g. details' `note`).
    get "#{tbase}/identity"
    assert_includes response.body, %(value="Renamed Co")
  end

  # --- pre_submit (dynamic conditional re-render) ----------------------------

  # A `pre_submit: true` input fires a form re-render on change. The re-rendered
  # step form must reflect the JUST-SUBMITTED values — exactly like the resource /
  # interaction pre_submit path — so a conditional input dependent on the changed
  # field appears/disappears. Seeding the re-render from STORED data only (the bug)
  # kept the conditional field hidden no matter what the user picked.
  test "pre_submit re-render reflects submitted values so a conditional field appears" do
    advance_through("identity") # now on details
    # `contact_email` is conditional on contact_pref == "email"; hidden initially.
    refute_includes response.body, %(name="wizard[contact_email]")

    post "#{tbase}/details",
      params: {wizard: {note: "hi", contact_pref: "email"}, pre_submit: "contact_pref"}
    assert_includes response.body, %(name="wizard[contact_email]"),
      "the conditional field should appear once pre_submit reflects the chosen value"
  end

  # The pre_submit re-render also keeps the OTHER just-typed values (so the user
  # doesn't lose what they entered when the form swaps).
  test "pre_submit re-render keeps the other submitted values" do
    advance_through("identity") # now on details
    post "#{tbase}/details",
      params: {wizard: {note: "keep me", contact_pref: "email"}, pre_submit: "contact_pref"}
    assert_includes response.body, "keep me",
      "sibling values typed before the pre_submit must survive the re-render"
  end

  # A pre_submit is render-only: it must NOT persist the step or move the cursor,
  # so the step stays outstanding on review until really submitted.
  test "pre_submit does not persist the step" do
    advance_through("identity") # on details (never submitted)
    post "#{tbase}/details",
      params: {wizard: {note: "hi", contact_pref: "email"}, pre_submit: "contact_pref"}
    get "#{tbase}/review"
    assert_includes response.body, %(data-wizard-review-fix="details"),
      "a pre_submit must not mark the step submitted"
  end

  # --- forward button labels + Save & review shortcut (§7) -------------------

  def forward_button = response.body[/<button[^>]*data-wizard-nav="next"[^>]*>.*?<\/button>/m]

  def review_shortcut_button = response.body[/<button[^>]*data-wizard-nav="save_review"[^>]*>.*?<\/button>/m]

  test "a freshly-reached, unsubmitted step shows a plain Next" do
    advance_through("identity") # cursor on details: reached but not submitted
    assert_includes forward_button, "Next"
    refute_includes forward_button, "Save"
    refute_includes response.body, %(data-wizard-nav="save_review")
  end

  test "revisiting an already-submitted step labels the forward button Save & continue" do
    advance_through("identity", "details") # identity submitted; cursor on profile
    get "#{tbase}/identity"
    assert_response :success
    assert_includes forward_button, "Save &amp; continue" # HTML-escaped ampersand
  end

  test "when every step is complete an earlier step offers Save & review as primary" do
    advance_through("identity", "details", "profile", "members") # all complete; on review
    get "#{tbase}/identity"
    assert_response :success

    # The shortcut is present, carries `_goto=review`, and is the primary button.
    assert review_shortcut_button, "expected a Save & review shortcut button"
    assert_includes review_shortcut_button, %(name="_goto")
    assert_includes review_shortcut_button, %(value="review")
    assert_includes review_shortcut_button, "pu-btn-primary"

    # Save & continue is the secondary (outline) forward action.
    assert_includes forward_button, "Save &amp; continue"
    assert_includes forward_button, "pu-btn-outline"
  end

  test "Save & review stages the edited step then jumps straight to review" do
    advance_through("identity", "details", "profile", "members")
    get "#{tbase}/identity"
    # The Save & review button posts `_goto=review` with NO `_direction`.
    post "#{tbase}/identity", params: {wizard: {name: "Edited Co", plan: "pro"}, _goto: "review"}
    assert_response :redirect
    assert_match %r{/review\z}, URI(response.location).path

    follow_redirect!
    assert_includes response.body, "Edited Co" # the edit was staged
  end

  test "the last step before review does not show the redundant Save & review shortcut" do
    advance_through("identity", "details", "profile")
    # Complete members (the last non-review step) so everything is complete.
    post "#{tbase}/members", params: {wizard: {invites: [{email: "x@y.com", role: "admin"}]}, _direction: "next"}
    follow_redirect! # review
    get "#{tbase}/members"
    assert_response :success
    # Next step IS review → the shortcut would be redundant, so it's hidden.
    refute_includes response.body, %(data-wizard-nav="save_review")
    assert_includes forward_button, "Save &amp; continue"
  end

  # Finish/Cancel redirect OUT of the wizard to a differently-structured page. The
  # layout opts into Turbo morphing, so without opting these submitters out of
  # Turbo the destination morphs INTO the wizard DOM (nesting it). In-wizard
  # Next/Back stay on Turbo (same structure → morph is correct).
  test "exit controls (Finish, Cancel) opt out of Turbo; in-wizard nav does not" do
    advance_through("identity", "details", "profile", "members") # → review
    finish_btn = response.body[/<button[^>]*data-wizard-nav="finish"[^>]*>/]
    assert_includes finish_btn, %(data-turbo="false"), "Finish must do a full navigation"

    # On a step page, Cancel exits → its mini-form opts out of Turbo; Next does not.
    get "#{tbase}/identity"
    assert_response :success
    cancel_form = response.body[/<form[^>]*>\s*<input[^>]*name="authenticity_token"[^>]*>\s*<input[^>]*value="cancel"[^>]*>.*?<\/form>/m]
    assert cancel_form, "expected the Cancel mini-form"
    assert_includes cancel_form, %(data-turbo="false")
    refute_includes forward_button, %(data-turbo="false"), "in-wizard Next stays on Turbo"
  end

  test "back direction moves to the previous step without validating" do
    advance_through("identity")
    post "#{tbase}/details", params: {_direction: "back"}
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, %(name="wizard[name]")
  end

  test "cancel clears the wizard session and redirects out" do
    advance_through("identity")
    assert_operator Plutonium::Wizard::Session.count, :>=, 1

    post "#{tbase}/identity", params: {_direction: "cancel"}
    assert_response :redirect
    assert_equal 0, Plutonium::Wizard::Session.where(status: "in_progress").count
  end

  # --- cancel returns to the launch origin (return_to) --------------------------

  # The tokened wizard mints its run-id into the launch redirect URL (the row is
  # written on the first POST), so read the token from the redirect.
  def launch_token
    URI(response.location).path[%r{/onboarding/([A-Za-z0-9]{32})/}, 1]
  end

  test "cancel returns to the launch origin captured from the referer" do
    get base, headers: {"HTTP_REFERER" => "http://www.example.com/admin/companies"}
    assert_response :redirect
    token = launch_token
    assert token, "launch redirects into a tokened run URL"

    post "#{base}/#{token}/identity", params: {_direction: "cancel"}
    assert_response :redirect
    assert_equal "/admin/companies", URI(response.location).path
  end

  test "an explicit ?return_to wins over the referer" do
    get "#{base}?return_to=/admin/widgets",
      headers: {"HTTP_REFERER" => "http://www.example.com/admin/companies"}
    token = launch_token

    post "#{base}/#{token}/identity", params: {_direction: "cancel"}
    assert_equal "/admin/widgets", URI(response.location).path
  end

  test "a cross-host referer is ignored; cancel falls back to root" do
    get base, headers: {"HTTP_REFERER" => "http://evil.example/phish"}
    token = launch_token

    post "#{base}/#{token}/identity", params: {_direction: "cancel"}
    assert_response :redirect
    refute_includes URI(response.location).to_s, "evil.example",
      "a foreign-host referer must never become the redirect target"
  end

  # §4: a wizard with no `concurrency_key` (OnboardOrganizationWizard) is
  # TOKENED/REPEATABLE — identity is the per-launch `wizard_token`. For an
  # AUTHENTICATED run the token rides the URL `:token` segment (owner-scoped on the
  # row), so resuming via the token-carrying URL re-uses the same instance_key →
  # the SAME row (not forked). The owner is stamped for listing.
  test "authenticated tokened wizard resumes via its URL token, not forks" do
    advance_through("identity")
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count

    row = Plutonium::Wizard::Session.where(status: "in_progress").sole
    assert row.token.present?, "a tokened (no concurrency_key) wizard mints a token"
    assert_equal @admin.to_global_id.to_s, row.owner.to_global_id.to_s

    # Resuming via the token-carrying URL does not spawn a second row.
    get "#{base}/#{row.token}/identity"
    assert_response :success
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count

    # The rendered form action carries the token, so the next POST stays on this run.
    assert_includes response.body, "#{base}/#{row.token}/"
  end
end

# Drives ChromelessWizard, which opts out of the chrome: `stepper false` (no top
# rail) and `review summary: false` with no custom block (→ the built-in "ready
# to complete" panel).
class AdminPortal::WizardChromeTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    Plutonium::Wizard::Session.delete_all
  end

  def base = "/admin/chromeless"

  test "stepper false hides the top rail" do
    get "#{base}/only"
    assert_response :success
    refute_includes response.body, "pu-wizard-stepper", "stepper false must hide the top rail"
  end

  test "a complete summary-off review with no custom block renders the ready panel" do
    get base
    follow_redirect!
    token = Plutonium::Wizard::Session.where(status: "in_progress").first&.token
    post "#{base}/#{token}/only", params: {wizard: {name: "Acme"}, _direction: "next"}
    follow_redirect! # lands on review (complete)

    assert_response :success
    # :ready mode — the built-in confirmation panel, not the auto-summary.
    assert_includes response.body, %(data-wizard-review-ready)
    assert_match(/You.{0,6}re all set/, response.body) # HTML-escaped apostrophe (&#39;)
    refute_includes response.body, %(data-wizard-review-step=)
    # `header: false` drops the step-header section — no "Done" heading on the card.
    refute_match(/<h2[^>]*>Done<\/h2>/, response.body)
    # The header carries no canned review prompt that would contradict the panel.
    refute_includes response.body, "Check everything over before you finish"
    # Finish is enabled (the single step is complete).
    finish_btn = response.body[/<button[^>]*data-wizard-nav="finish"[^>]*>/]
    refute_includes finish_btn, "disabled"
  end

  # ChromelessWizard declares `on_relaunch :new`, opting OUT of the default
  # resume-or-new chooser: a bare relaunch silently mints a fresh run even when a
  # pending one exists. (Guards the opt-out against the `:prompt` default.)
  test "on_relaunch :new forks a fresh run instead of prompting" do
    get base
    follow_redirect!
    first_token = Plutonium::Wizard::Session.where(status: "in_progress").first&.token
    post "#{base}/#{first_token}/only", params: {wizard: {name: "Acme"}, _direction: "next"}
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count

    get base
    assert_response :redirect, "must fork silently, not render the resume-or-new chooser"
    assert_match %r{\A#{Regexp.escape(base)}/[A-Za-z0-9]{32}/only\z}, URI(response.location).path
    new_token = URI(response.location).path[%r{/chromeless/([^/]+)/}, 1]
    refute_equal first_token, new_token, "the relaunch forks a new run, not the pending one"
  end

  # --- reachability guard: a POST to an unreachable step is refused -----------

  # Regression: advancing into a branch that HIDES a later step must not let a
  # forged/stale POST to that hidden step run its on_submit. The driver aborts
  # (PRG back to the run's current step) when the runner can't align the cursor
  # to the posted step.
  test "POST to a branch-hidden step is refused and its on_submit never runs" do
    BranchGuardWizard.fired.clear
    bg = "/admin/branch-guard"

    get bg
    token = URI(response.location).path[%r{/branch-guard/([^/]+)/}, 1]
    run = "#{bg}/#{token}"

    # Choose the branch that HIDES :secret — the run advances past it to review.
    post "#{run}/choice", params: {wizard: {mode: "no"}, _direction: "next"}
    follow_redirect!

    # Forge a POST straight to the now-hidden :secret step.
    post "#{run}/secret", params: {wizard: {note: "x"}, _direction: "next"}

    assert_empty BranchGuardWizard.fired,
      "on_submit must not run for a step the user can't reach"
    assert_response :redirect
    refute_match %r{/secret\z}, URI(response.location).path,
      "the refused POST should PRG back to the current step, not the hidden one"
  end

  # Regression: a branch step the cursor LANDS on (so it's `visited`) but that was
  # never submitted must read as `incomplete` on the rail — never a done-check — so
  # the rail agrees with the review's "needs attention" gating.
  test "a reached-but-unsubmitted branch step shows incomplete on the rail, not a checkmark" do
    bg = "/admin/branch-guard"
    get bg
    token = URI(response.location).path[%r{/branch-guard/([^/]+)/}, 1]
    run = "#{bg}/#{token}"

    # Choice = no → :secret hidden, advance to review.
    post "#{run}/choice", params: {wizard: {mode: "no"}, _direction: "next"}
    follow_redirect!
    # Edit choice → yes → :secret becomes visible; the cursor lands on it (so it's
    # visited) but it is never submitted.
    post "#{run}/choice", params: {wizard: {mode: "yes"}, _direction: "next"}
    follow_redirect! # now on :secret

    get "#{run}/review"
    assert_response :success

    # The review gates :secret as outstanding ...
    assert_includes response.body, "wizard-review-outstanding"
    assert_includes response.body, %(data-wizard-review-fix="secret")

    # ... and the rail AGREES: :secret is `incomplete` (not `completed`), while the
    # submitted :choice is `completed`.
    secret_state = response.body[%r{<li data-state="([a-z]+)"[^>]*>(?:(?!</li>).)*?Secret}m, 1]
    choice_state = response.body[%r{<li data-state="([a-z]+)"[^>]*>(?:(?!</li>).)*?Choice}m, 1]
    assert_equal "incomplete", secret_state, "reached-but-unsubmitted step is not a checkmark"
    assert_equal "completed", choice_state
  end
end

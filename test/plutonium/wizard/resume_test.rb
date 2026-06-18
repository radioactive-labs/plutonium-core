# frozen_string_literal: true

require "test_helper"

# Drives the "continue where you left off" listing (§4.5):
#
# - The public, ergonomic API `Plutonium::Wizard.in_progress_for(view_context)`
#   (and the module method `Resume.entries_for(view_context)` it delegates to) take
#   the view_context (as interactions do) and derive the run owner (`current_user`)
#   and tenant scope (`current_scoped_entity` when `scoped_to_entity?`, else nil)
#   from it. A non-scoped portal lists only unscoped runs; a scoped portal narrows
#   to its tenant — a run is only ever listed by the portal it belongs to.
#
# Each entry carries the wizard's label/icon, current step (+ label), updated_at,
# and a resolved resume_url (or nil with a reason when a mount can't be resolved
# generically).
class Plutonium::Wizard::ResumeTest < ActiveSupport::TestCase
  # Minimal controller/view_context doubles mirroring the real accessor path used
  # by `Plutonium::Wizard.in_progress_for`: `view_context.controller.helpers
  # .current_user`, `controller.scoped_to_entity?`, `controller.current_scoped_entity`.
  FakeController = Struct.new(:current_user, :scoped_to_entity, :current_scoped_entity, :current_engine) do
    def helpers = self
    def scoped_to_entity? = scoped_to_entity
  end
  # `current_scoped_entity`/`current_engine` are helper_methods, read off the view
  # context (not the controller) — mirror that by delegating to the controller.
  FakeViewContext = Struct.new(:controller) do
    def current_scoped_entity = controller.current_scoped_entity
    def current_engine = controller.current_engine
  end

  # The engine string a row carries when launched in each portal (what `entries_for`
  # filters on, via `current_engine.name`).
  ADMIN = "AdminPortal::Engine"
  ORG = "OrgPortal::Engine"

  def view_context_for(owner, scoped_to_entity: false, scope: nil, engine: AdminPortal::Engine)
    FakeViewContext.new(FakeController.new(owner, scoped_to_entity, scope, engine))
  end

  setup do
    Plutonium::Wizard::Session.delete_all
    Rails.application.reload_routes!
    @owner = Admin.create!(email: "owner-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @other = Admin.create!(email: "other-#{SecureRandom.hex(4)}@example.com", password: "password123")
    @org = Organization.create!(name: "Acme #{SecureRandom.hex(4)}")
    @other_org = Organization.create!(name: "Beta #{SecureRandom.hex(4)}")
  end

  def session!(**attrs)
    Plutonium::Wizard::Session.create!(
      {status: "in_progress", instance_key: SecureRandom.hex(16), engine: ADMIN}.merge(attrs)
    )
  end

  test "public in_progress_for(view_context) lists only the owner's runs, enriched" do
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner, token: "t1")
    session!(wizard: "OnboardOrganizationWizard", current_step: "identity", owner: @other)

    entries = Plutonium::Wizard.in_progress_for(view_context_for(@owner))
    assert_equal 1, entries.size
    entry = entries.first
    assert_equal OnboardOrganizationWizard, entry.wizard_class
    assert_equal "Onboard an organization", entry.label
    assert_equal "details", entry.current_step
    assert_equal "Details", entry.current_step_label
    refute_nil entry.updated_at
  end

  # A guest surface stubs `current_user` to "Guest". A guest has no owner-tracked
  # runs (anonymous runs are session-keyed + ownerless), so the list is empty —
  # and it must NOT leak other guests' ownerless runs (no `where(owner: nil)`).
  test "a guest surface lists nothing and never leaks ownerless runs" do
    session!(wizard: "GuestSignupWizard", current_step: "account", owner: nil)
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner)

    assert_empty Plutonium::Wizard.in_progress_for(view_context_for("Guest"))
  end

  test "public in_progress_for loads only runs matching the current portal's scoping" do
    unscoped = session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner)
    session!(wizard: "ConfigureOrgWizard", current_step: "rename", owner: @owner, scope: @org, engine: ORG)
    session!(wizard: "ConfigureOrgWizard", current_step: "rename", owner: @owner, scope: @other_org, engine: ORG)

    # Non-scoped portal (scoped_to_entity? == false) loads ONLY unscoped runs —
    # entity-scoped runs belong to a scoped portal, not this one.
    plain = Plutonium::Wizard.in_progress_for(view_context_for(@owner))
    assert_equal [unscoped.id], plain.map { |e| e.session.id }

    # Scoped portal → narrows to the current tenant's run.
    scoped_vc = view_context_for(@owner, scoped_to_entity: true, scope: @org, engine: OrgPortal::Engine)
    scoped = Plutonium::Wizard.in_progress_for(scoped_vc)
    assert_equal 1, scoped.size
    assert_equal @org, scoped.first.session.scope
  end

  # The portal is recorded per-run, so a run launched in ANOTHER portal is never
  # listed here — even when owner and scope match (two non-scoped portals, or two
  # portals sharing an entity scope, can't be told apart by scope alone).
  test "a run from another portal is not listed even when owner and scope match" do
    here = session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner)
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner,
      engine: "StorefrontPortal::Engine")

    listed = Plutonium::Wizard.in_progress_for(view_context_for(@owner)) # admin portal
    assert_equal [here.id], listed.map { |e| e.session.id }
  end

  test "excludes completed runs" do
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner, status: "completed")
    assert_empty Plutonium::Wizard.in_progress_for(view_context_for(@owner))
  end

  # --- resume_url resolution per mount type -----------------------------------

  # A register_wizard (portal-level) run resolves through its named route. The
  # resource-mounted ANCHORED member case is covered by a real-controller
  # integration test (test/integration/org_portal/wizard_resume_url_test.rb), since
  # it builds the URL through the portal's `resource_url_for`.

  test "a register_wizard portal-level tokened run resolves a token-carrying URL" do
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner, token: "tok-xyz")
    entry = Plutonium::Wizard::Resume.entries_for(view_context_for(@owner)).first
    assert_equal "/admin/onboarding/tok-xyz/details", entry.resume_url
    assert_nil entry.resume_unresolved_reason
  end

  test "a register_wizard entity-scoped keyed run resolves a scoped URL (no token)" do
    session!(wizard: "ConfigureOrgWizard", current_step: "rename", owner: @owner, scope: @org, engine: ORG)
    vc = view_context_for(@owner, scoped_to_entity: true, scope: @org, engine: OrgPortal::Engine)
    entry = Plutonium::Wizard::Resume.entries_for(vc).first
    assert_equal "/org/#{@org.to_param}/configure/rename", entry.resume_url
    assert_nil entry.resume_unresolved_reason
  end

  test "an unresolvable mount returns nil with a reason rather than raising" do
    # A wizard with no register_wizard route and no anchor on the row: the resolver
    # has nothing to rebuild a URL from.
    session!(wizard: "ConfigureWidgetWizard", current_step: "rename", owner: @owner)
    entry = Plutonium::Wizard::Resume.entries_for(view_context_for(@owner)).first
    assert_nil entry.resume_url
    assert_match(/no .*route|resource identity/i, entry.resume_unresolved_reason)
  end
end

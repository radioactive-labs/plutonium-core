# frozen_string_literal: true

require "test_helper"

# Drives the "continue where you left off" listing (§4.5):
# `Plutonium::Wizard.in_progress_for(owner, scope:)` returns enriched, owner- and
# scope-narrowed entries, each with the wizard's label/icon, current step (+
# label), updated_at, and a resolved resume_url (or nil with a reason when a mount
# can't be resolved generically).
class Plutonium::Wizard::ResumeTest < ActiveSupport::TestCase
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
      {status: "in_progress", instance_key: SecureRandom.uuid}.merge(attrs)
    )
  end

  test "lists only the owner's in-progress runs, enriched with label and step" do
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner, token: "t1")
    session!(wizard: "OnboardOrganizationWizard", current_step: "identity", owner: @other)

    entries = Plutonium::Wizard.in_progress_for(@owner)
    assert_equal 1, entries.size
    entry = entries.first
    assert_equal OnboardOrganizationWizard, entry.wizard_class
    assert_equal "Onboard an organization", entry.label
    assert_equal "details", entry.current_step
    assert_equal "Details", entry.current_step_label
    refute_nil entry.updated_at
  end

  test "scope narrows the listing to that tenant" do
    session!(wizard: "ConfigureOrgWizard", current_step: "rename", owner: @owner, scope: @org)
    session!(wizard: "ConfigureOrgWizard", current_step: "rename", owner: @owner, scope: @other_org)

    all = Plutonium::Wizard.in_progress_for(@owner)
    assert_equal 2, all.size

    scoped = Plutonium::Wizard.in_progress_for(@owner, scope: @org)
    assert_equal 1, scoped.size
    assert_equal @org, scoped.first.session.scope
  end

  test "excludes completed runs" do
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner, status: "completed")
    assert_empty Plutonium::Wizard.in_progress_for(@owner)
  end

  # --- resume_url resolution per mount type -----------------------------------

  test "a register_wizard portal-level tokened run resolves a token-carrying URL" do
    session!(wizard: "OnboardOrganizationWizard", current_step: "details", owner: @owner, token: "tok-xyz")
    entry = Plutonium::Wizard.in_progress_for(@owner).first
    assert_equal "/admin/onboarding/tok-xyz/details", entry.resume_url
    assert_nil entry.resume_unresolved_reason
  end

  test "a register_wizard entity-scoped keyed run resolves a scoped URL (no token)" do
    session!(wizard: "ConfigureOrgWizard", current_step: "rename", owner: @owner, scope: @org)
    entry = Plutonium::Wizard.in_progress_for(@owner).first
    assert_equal "/org/#{@org.to_param}/configure/rename", entry.resume_url
    assert_nil entry.resume_unresolved_reason
  end

  test "a resource-mounted anchored run resolves the member URL from its anchor" do
    widget = Widget.create!(name: "W", organization: @org)
    session!(wizard: "ConfigureWidgetWizard", current_step: "rename",
      owner: @owner, scope: @org, anchor: widget)
    entry = Plutonium::Wizard.in_progress_for(@owner).first
    assert_equal "/org/#{@org.to_param}/widgets/#{widget.to_param}/wizards/configure/rename",
      entry.resume_url
    assert_nil entry.resume_unresolved_reason
  end

  test "an unresolvable mount returns nil with a reason rather than raising" do
    # A wizard with no register_wizard route and no anchor on the row: the resolver
    # has nothing to rebuild a URL from.
    session!(wizard: "ConfigureWidgetWizard", current_step: "rename", owner: @owner)
    entry = Plutonium::Wizard.in_progress_for(@owner).first
    assert_nil entry.resume_url
    assert_match(/no .*route|resource identity/i, entry.resume_unresolved_reason)
  end
end

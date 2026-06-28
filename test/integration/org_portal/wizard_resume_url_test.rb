# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Resume URL resolution for a RESOURCE-MOUNTED anchored wizard, driven through a
# REAL entity-scoped portal controller (so the URL is built by the same
# `resource_url_for(record, wizard:, step:)` machinery the launch button uses —
# portal- and scope-correct by construction, not a hand-rolled route scan).
class OrgPortal::WizardResumeUrlTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @widget = Widget.create!(name: "W", organization: @org)
    login_as(@user, portal: :user)
    Plutonium::Wizard::Session.delete_all
  end

  test "in_progress_for resolves a resource-mounted anchored run's member URL via the current portal" do
    Plutonium::Wizard::Session.create!(
      status: "in_progress", instance_key: SecureRandom.hex(16),
      wizard: "ConfigureWidgetWizard", current_step: "rename",
      owner: @user, scope: @org, anchor: @widget, engine: "OrgPortal::Engine"
    )

    # A real request establishes the scoped portal controller; reuse its
    # view_context (same as a dashboard rendering the resume list would).
    get "/org/#{@org.to_param}/"
    entries = Plutonium::Wizard.in_progress_for(@controller.view_context)

    assert_equal 1, entries.size
    assert_equal "/org/#{@org.to_param}/widgets/#{@widget.to_param}/wizards/configure/rename",
      entries.first.resume_url
    assert_nil entries.first.resume_unresolved_reason
  end
end

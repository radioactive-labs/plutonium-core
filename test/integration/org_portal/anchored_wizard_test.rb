# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Drives an ANCHORED wizard auto-mounted on the resource controller (§5.1 / Fix A)
# through the entity-scoped org portal. Proves:
#
# - the wizard launches at `/org/:org/widgets/:id/wizards/configure/:step`, drives
#   advance → finalize, and `execute` updates THAT widget (the anchor);
# - the anchor is resolved through the resource controller's scoped, policy-gated
#   `resource_record!` — so a widget id outside the portal's authorized scope (a
#   different org's widget) and a non-existent id both 404, rather than loading
#   another tenant's record (the IDOR fix). This mirrors how interactive record
#   actions resolve their subject.
class OrgPortal::AnchoredWizardTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @widget = Widget.create!(name: "Original", organization: @org)

    # Another tenant's widget — must be invisible to @user's scoped portal.
    @other_org = create_organization!
    @other_widget = Widget.create!(name: "Other Org Widget", organization: @other_org)

    login_as(@user, portal: :user)
    Plutonium::Wizard::Session.delete_all
  end

  def prefix = "/org/#{@org.to_param}"
  def base = "#{prefix}/widgets/#{@widget.id}/wizards/configure"

  test "GET the bare wizard mount launches: redirects to the first step (keyed)" do
    get base
    assert_response :redirect
    # ConfigureWidgetWizard is `anchored with: Widget` with NO explicit
    # concurrency_key, so it's IMPLICITLY keyed by [widget, current_user] (tenant
    # folded). The run is identified by that key — the launch lands on the first
    # step with NO URL token, and re-launching resumes it.
    assert_equal "#{base}/rename", URI(response.location).path
  end

  test "implicitly keyed by [widget, user]: a second launch resumes, not forks" do
    post "#{base}/rename", params: {wizard: {name: "Draft"}, _direction: "next"}
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count

    get base # re-launch the same widget as the same user
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count,
      "an anchored wizard with no explicit concurrency_key resumes its keyed run"
  end

  test "GET the first step renders the anchored wizard's step form" do
    get "#{base}/rename"
    assert_response :success
    assert_includes response.body, %(name="wizard[name]")
    assert_includes response.body, %(name="_direction")
  end

  test "advance then finish updates the anchored record (PRG)" do
    post "#{base}/rename", params: {wizard: {name: "Renamed"}, _direction: "next"}
    assert_response :redirect
    follow_redirect! # now on review

    # Keyed by [widget, user] → the run is resolved from the URL (the widget id) +
    # the key, so a bare POST to the same URL stays on this run (no token to thread).
    assert_no_difference -> { Widget.count } do
      post "#{base}/review", params: {_direction: "next"}
    end
    assert_response :redirect

    assert_equal "Renamed", @widget.reload.name
  end

  # --- IDOR: the anchor is scoped, never an unscoped find_by --------------------

  test "a widget id outside the portal's authorized scope returns not-found" do
    other = "#{prefix}/widgets/#{@other_widget.id}/wizards/configure/rename"
    get other
    assert_response :not_found
    # The cross-tenant widget is untouched (never loaded as the anchor).
    assert_equal "Other Org Widget", @other_widget.reload.name
  end

  test "a non-existent widget id returns not-found" do
    get "#{prefix}/widgets/0/wizards/configure/rename"
    assert_response :not_found
  end

  test "an unknown wizard name 404s (route mounted, gated like interactions)" do
    get "#{prefix}/widgets/#{@widget.id}/wizards/nope/rename"
    assert_response :not_found
  end
end

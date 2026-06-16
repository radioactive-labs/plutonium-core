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

  test "GET the bare wizard mount launches: redirects to the first step with a token" do
    get base
    assert_response :redirect
    # Tokened anchored wizard → the launch mints the per-run :token and lands on the
    # first step, so the run URL is stable/shareable from the first paint.
    assert_match %r{\A#{Regexp.escape(base)}/[A-Za-z0-9]{32}/rename\z}, URI(response.location).path
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

    # ConfigureWidgetWizard has no concurrency_key → tokened identity; the per-run
    # id rides the URL (§4.5), so thread it through the finalize POST to stay on
    # this run (a bare POST would fork a fresh, empty tokened run).
    token = Plutonium::Wizard::Session.where(status: "in_progress").sole.token
    assert_no_difference -> { Widget.count } do
      post "#{base}/#{token}/review", params: {_direction: "next"}
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

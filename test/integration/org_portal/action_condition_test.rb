# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Verifies the `condition:` arg on actions: an action declared with a
# `condition:` proc is display-only — it renders only when the proc, evaluated
# against the request's view context, returns truthy. It is NOT an
# authorization gate; that stays in the policy. See Catalog::ProductDefinition's
# `:param_gated_demo` action (condition: -> { params[:show_demo] == "1" }).
class OrgPortal::ActionConditionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    @product = create_product!(category: @category, user: @user, organization: @org, status: :draft)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  # `object` is the shown record on the show page: rendered when draft …
  test "record-scoped condition renders when object matches" do
    get "#{prefix}/catalog/products/#{@product.id}"

    assert_response :success
    assert_includes response.body, "record_actions/draft_only_demo",
      "expected the draft-only action shown for a draft product"
  end

  # … and hidden when not.
  test "record-scoped condition is hidden when object does not match" do
    active = create_product!(category: @category, user: @user, organization: @org, status: :active)

    get "#{prefix}/catalog/products/#{active.id}"

    assert_response :success
    refute_includes response.body, "record_actions/draft_only_demo",
      "expected the draft-only action hidden for a non-draft product"
  end

  # Conditions also delegate to the view context (params/request/current_user/…).
  test "view-context condition is hidden when its condition is falsy" do
    get "#{prefix}/catalog/products/#{@product.id}"

    assert_response :success
    refute_includes response.body, "record_actions/param_gated_demo",
      "expected the param-gated action hidden when params[:show_demo] is absent"
  end

  test "view-context condition renders when its condition is truthy" do
    get "#{prefix}/catalog/products/#{@product.id}?show_demo=1"

    assert_response :success
    assert_includes response.body, "record_actions/param_gated_demo",
      "expected the param-gated action shown when params[:show_demo] == '1'"
  end

  # The headline use case: condition: hides the button but the route stays
  # live, so the action is still reachable (e.g. API / programmatic call).
  # condition: is display-only, NOT authorization.
  test "conditional action route is still reachable while its button is hidden" do
    # No show_demo param → button is hidden (asserted above) …
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/param_gated_demo",
      headers: {"Turbo-Frame" => "remote_modal"}

    # … yet the endpoint still responds.
    assert_response :success
  end
end

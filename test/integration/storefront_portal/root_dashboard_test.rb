# frozen_string_literal: true

require "test_helper"

# A dashboard registered `at: "/"` is the portal's root page. The synthesized
# controller must resolve bare route helpers (`root_path` in the sidebar)
# against the portal's routes, not the main app's: `Class.new(parent)` runs
# Rails' `inherited` hook while the class is still anonymous, which includes
# the application's URL helpers over the engine's unless corrected.
class StorefrontPortal::RootDashboardTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  test "the root mount serves the dashboard page" do
    get "/storefront"
    assert_response :success
    assert_match(%r{<h1[^>]*>.*Home}m, response.body)
    assert_match(%r{<turbo-frame[^>]*src="/storefront/dashboards/home/cards/products"}, response.body)
  end

  test "the cards are served under the dashboards segment" do
    get "/storefront/dashboards/home/cards/products", headers: {"Turbo-Frame" => "pu-dashboard-card-products"}
    assert_response :success
    assert_match(/pu-metric-value/, response.body)
  end

  test "the sidebar's home link stays inside the portal on the dashboard page" do
    get "/storefront"
    home = response.body[%r{<a [^>]*icon-rail-leaf[^>]*>}]
    assert_match(%r{href="/storefront/?"}, home)
  end

  test "the root dashboard is the home link, not a Dashboards group entry" do
    get "/storefront"
    refute_match(/icon-rail-flyout-label[^>]*>Dashboards</, response.body)
  end

  test "the synthesized controller uses the portal's routes" do
    assert_equal StorefrontPortal::Engine.routes, StorefrontPortal::DashboardsController.new._routes
  end
end

# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# End-to-end coverage of a `register_dashboard` mount: the page renders one
# lazy turbo frame per visible card, the card endpoint answers each frame,
# hidden and unknown cards are 404s, and `authorize?` gates both.
class AdminPortal::DashboardTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    reset_switches
    @local = Rails.application.config.consider_all_requests_local
  end

  teardown do
    reset_switches
    Rails.application.config.consider_all_requests_local = @local
  end

  def reset_switches
    OverviewDashboard.show_secret = false
    OverviewDashboard.break_inline = false
    OverviewDashboard.inline_secret_runs = 0
  end

  def base = "/admin/dashboards/overview"

  def get_frame(path, frame)
    get path, headers: {"Turbo-Frame" => frame}
  end

  # The opening tag of the turbo frame with that id, attribute order aside.
  def frame_tag(id)
    response.body[/<turbo-frame[^>]*\bid="#{Regexp.escape(id)}"[^>]*>/]
  end

  test "the page renders the header and one lazy frame per visible card" do
    get base
    assert_response :success

    assert_match(/<title>Overview \| /, response.body)
    assert_match(/<h1[^>]*>Overview<\/h1>/, response.body)
    assert_match(/Everything at a glance/, response.body)
    assert_match(/class="pu-dashboard grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-12"/, response.body)

    %w[users organizations churn signups by-kind welcome].each do |key|
      frame = frame_tag("pu-dashboard-card-#{key}")
      assert frame, "expected a frame for #{key}"
      assert_includes frame, %(src="/admin/dashboards/overview/cards/#{key.tr("-", "_")}")
      assert_includes frame, %(loading="lazy")
      assert_includes frame, %(refresh="morph")
    end

    # A hidden card draws no frame at all, so nothing hints at its endpoint.
    refute_match(/pu-dashboard-card-secret/, response.body)
    refute_match(%r{cards/secret}, response.body)

    # The lazy frames hold a skeleton, not the card.
    assert_match(/pu-dashboard-skeleton/, response.body)
    assert_match(/Loading Users\.\.\./, response.body)
  end

  test "spans and refresh ride the frame" do
    get base
    assert_includes frame_tag("pu-dashboard-card-users"), %(class="block lg:col-span-3")
    assert_includes frame_tag("pu-dashboard-card-signups"), %(class="block md:col-span-2 lg:col-span-8")
    assert_includes frame_tag("pu-dashboard-card-by-kind"), %(class="block lg:col-span-4")
    assert_includes frame_tag("pu-dashboard-card-welcome"), %(class="block md:col-span-2 lg:col-span-12")

    churn = frame_tag("pu-dashboard-card-churn")
    assert_includes churn, %(data-controller="frame-refresh")
    assert_includes churn, %(data-frame-refresh-interval-value="30")
    refute_includes frame_tag("pu-dashboard-card-users"), "frame-refresh"
  end

  test "the dashboard takes the full width by default" do
    get base
    assert_match(/<div class="pu-dashboard-page">/, response.body)
  end

  test "a non-lazy card renders inline" do
    get base
    refute frame_tag("pu-dashboard-card-conversion")
    assert_match(/pu-dashboard-card-title[^>]*>Conversion</, response.body)
    assert_match(/pu-metric-value[^>]*>12\.5%</, response.body)
    assert_match(/>\+2\.3%</, response.body)
  end

  test "a hidden inline card is left out of the page and its block never runs" do
    get base
    assert_response :success
    refute_match(/Inline Secret/, response.body)
    assert_equal 0, OverviewDashboard.inline_secret_runs

    get_frame "#{base}/cards/inline_secret", "pu-dashboard-card-inline_secret"
    assert_response :not_found

    OverviewDashboard.show_secret = true
    get base
    assert_match(/pu-dashboard-card-title[^>]*>Inline Secret</, response.body)
    assert_match(/pu-metric-value[^>]*>7</, response.body)
    assert_equal 1, OverviewDashboard.inline_secret_runs
  end

  # An inline card renders with the page, under the same guard as a lazy one:
  # outside local-request mode its failure costs that card and nothing else.
  test "a failing inline card renders the notice and the rest of the page survives" do
    OverviewDashboard.break_inline = true
    Rails.application.config.consider_all_requests_local = false

    get base
    assert_response :success
    assert_match(/pu-dashboard-card-title[^>]*>Fragile</, response.body)
    assert_includes response.body, I18n.t("plutonium.dashboard.card_error")
    assert_match(/pu-metric-value[^>]*>12\.5%</, response.body)
    assert frame_tag("pu-dashboard-card-users")
  end

  # In local-request mode (development, test) the error is raised, and because
  # an inline card renders with the page it takes the whole page with it.
  test "in local-request mode a failing inline card fails the page" do
    OverviewDashboard.break_inline = true
    Rails.application.config.consider_all_requests_local = true

    error = assert_raises(ArgumentError) { get base }
    assert_equal "inline boom", error.message
  end

  test "a custom card renders its block with the dashboard's methods in scope" do
    get_frame "#{base}/cards/welcome", "pu-dashboard-card-welcome"
    assert_response :success
    assert_match(/Signed in as #{Regexp.escape(@admin.email)}/, response.body)
    assert_match(/Hello from the dashboard/, response.body)
  end

  test "the card endpoint answers its frame without the layout" do
    create_organization!
    create_organization!

    get_frame "#{base}/cards/organizations", "pu-dashboard-card-organizations"
    assert_response :success

    assert_match(%r{\A\s*<turbo-frame[^>]*id="pu-dashboard-card-organizations"}, response.body)
    refute_match(/<html/, response.body)
    assert_match(/pu-dashboard-card-title[^>]*>Organizations</, response.body)
    assert_match(/pu-dashboard-card-description[^>]*>Tenants on the platform</, response.body)
    assert_match(/pu-metric-value[^>]*>2</, response.body)
    # previous is 0, so no percentage: a neutral row with just the caption
    assert_match(/pu-metric-change-neutral/, response.body)
    refute_match(/pu-metric-change[^>]*>.*?<span class="font-medium">/, response.body)
    assert_match(/vs\. last month/, response.body)
  end

  test "a direct visit to a card URL renders it inside the layout" do
    get "#{base}/cards/users"
    assert_response :success
    assert_match(/<html/, response.body)
    assert_match(%r{<turbo-frame[^>]*id="pu-dashboard-card-users"}, response.body)
    assert_match(%r{<a href="/admin/users"[^>]*>Users</a>}, response.body)
  end

  test "a chart card serialises its data for the chart controller" do
    get_frame "#{base}/cards/by_kind", "pu-dashboard-card-by-kind"
    assert_response :success

    assert_match(/data-controller="chart"/, response.body)
    assert_match(/data-chart-type-value="PieChart"/, response.body)
    assert_match(/data-chart-options-value="\{&quot;donut&quot;:true\}"/, response.body)
    assert_match(/&quot;Users&quot;:0/, response.body)
    assert_match(%r{data-chart-script-value="/[^"]*plutonium-charts[^"]*\.js"}, response.body)
    assert_match(/style="height: 200px;"/, response.body)

    create_organization!
    get_frame "#{base}/cards/signups", "pu-dashboard-card-signups"
    assert_match(/data-chart-type-value="AreaChart"/, response.body)
    assert_match(/&quot;#{Date.current.iso8601}&quot;:1/, response.body)
  end

  test "unknown and hidden cards are not found" do
    get_frame "#{base}/cards/nope", "pu-dashboard-card-nope"
    assert_response :not_found

    get_frame "#{base}/cards/secret", "pu-dashboard-card-secret"
    assert_response :not_found

    OverviewDashboard.show_secret = true
    get_frame "#{base}/cards/secret", "pu-dashboard-card-secret"
    assert_response :success
    assert_match(/pu-metric-value[^>]*>42</, response.body)

    get base
    assert_match(/pu-dashboard-card-secret/, response.body)
  end

  test "authorize? false is forbidden on the page and on every card" do
    OverviewDashboard.alias_method(:__denied_authorize__, :authorize?)
    OverviewDashboard.define_method(:authorize?) { false }

    get base
    assert_response :forbidden

    get_frame "#{base}/cards/users", "pu-dashboard-card-users"
    assert_response :forbidden
  ensure
    OverviewDashboard.alias_method(:authorize?, :__denied_authorize__)
    OverviewDashboard.remove_method(:__denied_authorize__)
  end

  test "the sidebar groups the dashboards under a Dashboards parent" do
    get "/admin/users"

    flyout = response.body[%r{<div[^>]*class="icon-rail-flyout-inner".*?</div>\s*</div>}m]
    assert_match(%r{icon-rail-flyout-label[^>]*>Dashboards<}, flyout)
    assert_match(%r{href="/admin/dashboards/overview"[^>]*>Overview<}, flyout)
  end

  test "the page and cards require a signed-in admin" do
    sign_out(portal: :admin)
    get base
    assert_response :redirect

    get_frame "#{base}/cards/users", "pu-dashboard-card-users"
    assert_response :redirect
  end
end

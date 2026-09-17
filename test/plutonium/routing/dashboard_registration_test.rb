# frozen_string_literal: true

require "test_helper"

# `register_dashboard` draws against the dummy portals at boot; this covers
# the pieces that are cheaper to probe directly: argument validation, and the
# route-name resolution the controller and sidebar rely on (which must track
# `at:` / `as:` and an entity-scope prefix rather than the class name).
class Plutonium::Routing::DashboardRegistrationTest < Minitest::Test
  def mapper = Object.new.extend(Plutonium::Routing::DashboardRegistration)

  # The synthesized controllers and the engine registers only exist once the
  # routes have been drawn, which the test environment does lazily. Draw them
  # with `reload_routes!`, which every supported Rails version answers
  # (`routes_reloader.execute_unless_loaded` is Rails 8.0+).
  def setup
    Rails.application.reload_routes!
  end

  def test_rejects_a_class_that_is_not_a_dashboard
    err = assert_raises(ArgumentError) { mapper.register_dashboard(String, at: "x") }
    assert_match(/must subclass Plutonium::Dashboard::Base/, err.message)
  end

  def test_rejects_a_mapper_without_an_engine
    klass = Class.new(Plutonium::Dashboard::Base)
    klass.define_singleton_method(:name) { "OrphanDashboard" }
    err = assert_raises(ArgumentError) { mapper.register_dashboard(klass, at: "x") }
    assert_match(/Plutonium engine/, err.message)
  end

  def test_resolves_the_drawn_route_names_by_dashboard_class
    admin = AdminPortal::Engine.routes
    assert_equal :overview_dashboard, Plutonium::Dashboard::RouteResolution.route_name(admin, OverviewDashboard, action: "show")
    assert_equal :overview_dashboard_card, Plutonium::Dashboard::RouteResolution.route_name(admin, OverviewDashboard, action: "card")
    assert_nil Plutonium::Dashboard::RouteResolution.route_name(admin, TeamDashboard, action: "show")

    org = OrgPortal::Engine.routes
    assert_equal :organization_scoped_team_dashboard, Plutonium::Dashboard::RouteResolution.route_name(org, TeamDashboard, action: "show")
    assert_equal :organization_scoped_team_dashboard_card, Plutonium::Dashboard::RouteResolution.route_name(org, TeamDashboard, action: "card")
  end

  # Every non-root mount is drawn under `dashboards/`, so a dashboard can never
  # shadow (or be shadowed by) a `register_resource` route of the same name.
  def test_draws_the_mount_under_the_dashboards_segment
    paths = AdminPortal::Engine.routes.routes
      .select { |r| r.defaults[:dashboard_class] == "OverviewDashboard" }
      .to_h { |r| [r.defaults[:action], r.path.spec.to_s] }

    assert_equal "/dashboards/overview(.:format)", paths["show"]
    assert_equal "/dashboards/overview/cards/:card(.:format)", paths["card"]
  end

  # `prefix: nil` opts a mount out of the segment; the org portal's dashboard
  # is registered that way.
  def test_prefix_nil_draws_the_mount_at_the_bare_path
    paths = OrgPortal::Engine.routes.routes
      .select { |r| r.defaults[:dashboard_class] == "TeamDashboard" }
      .to_h { |r| [r.defaults[:action], r.path.spec.to_s] }

    assert_equal "/:organization_scoped/team(.:format)", paths["show"]
    assert_equal "/:organization_scoped/team/cards/:card(.:format)", paths["card"]
  end

  def test_synthesizes_a_portal_namespaced_controller
    controller = AdminPortal::DashboardsController
    assert_operator controller, :<, AdminPortal::PlutoniumController
    assert_includes controller.ancestors, Plutonium::Dashboard::Controller
    assert_includes controller.ancestors, AdminPortal::Concerns::Controller
  end

  def test_records_the_dashboard_on_the_engine_register
    assert_equal [OverviewDashboard], AdminPortal::Engine.dashboard_register.dashboards
    assert_equal [TeamDashboard], OrgPortal::Engine.dashboard_register.dashboards
  end
end

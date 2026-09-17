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

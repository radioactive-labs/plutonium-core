# frozen_string_literal: true

require "test_helper"

# A gem-style engine whose engine class IS the namespaced constant, with no
# nested ::Engine -- mirrors graphql-ruby's top-level Graphql::Dashboard.
# Defined at top level so "dummy_gem/dashboard".camelize.constantize resolves.
module DummyGem
  class Dashboard < ::Rails::Engine
  end
end

module Plutonium
  module Routing
    # Tests for RouteSetExtensions#determine_engine.
    #
    # determine_engine runs (via #engine) inside the unguarded #clear! during every
    # routes reload, for *every* engine's route set. It must therefore resolve the
    # owning engine for engines that do NOT follow Plutonium's SomeModule::Engine
    # naming convention -- e.g. graphql-ruby's Dashboard, whose engine class is
    # the module itself (class Dashboard < Rails::Engine) with no nested ::Engine.
    class DetermineEngineTest < Minitest::Test
      def determine_engine_for(scope_module)
        route_set = ActionDispatch::Routing::RouteSet.new
        scope = scope_module.nil? ? nil : {module: scope_module}
        route_set.define_singleton_method(:default_scope) { scope }
        route_set.send(:determine_engine)
      end

      def test_returns_application_when_scope_module_blank
        assert_equal Rails.application.class, determine_engine_for(nil)
        assert_equal Rails.application.class, determine_engine_for("")
      end

      def test_resolves_conventional_plutonium_engine
        assert_equal AdminPortal::Engine, determine_engine_for("admin_portal")
      end

      def test_returns_nil_for_engine_whose_class_is_the_module_itself
        # No DummyGem::Dashboard::Engine exists; the engine IS DummyGem::Dashboard.
        # The old implementation raised NameError here, breaking route reload.
        # It is not a Plutonium engine, so we manage nothing -> nil (skipped).
        assert_nil determine_engine_for("dummy_gem/dashboard")
      end

      def test_returns_nil_for_unresolvable_module
        assert_nil determine_engine_for("no/such/thing")
      end

      def test_clear_does_not_raise_or_touch_app_register_for_foreign_engine
        app_register = Rails.application.routes.engine.resource_register
        sentinel = Object.new
        app_register.instance_variable_set(:@__sentinel, sentinel)

        route_set = ActionDispatch::Routing::RouteSet.new
        route_set.define_singleton_method(:default_scope) { {module: "dummy_gem/dashboard"} }

        route_set.clear! # the exact unguarded path that raised NameError during reload

        # App register was left untouched (not cleared via the wrong engine).
        assert_same sentinel, app_register.instance_variable_get(:@__sentinel)
      ensure
        app_register&.remove_instance_variable(:@__sentinel)
      end
    end
  end
end

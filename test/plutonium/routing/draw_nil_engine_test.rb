# frozen_string_literal: true

require "test_helper"

# A gem-style engine whose engine class IS the namespaced constant, with no
# nested ::Engine -- mirrors graphql-ruby's top-level Graphql::Dashboard.
# Defined at top level so "dummy_gem_for_draw_test/dashboard".camelize resolves.
# determine_engine returns nil for it (no DummyGemForDrawTest::Dashboard::Engine),
# so #draw must skip Plutonium handling and delegate to super rather than raise.
module DummyGemForDrawTest
  class Dashboard < ::Rails::Engine
  end
end

module Plutonium
  module Routing
    # Regression tests for RouteSetExtensions#draw with a nil engine.
    #
    # Commit 54af907 added a nil guard to #clear! but not to #draw, so #draw
    # called supported_engine?(nil), which raised NoMethodError on nil.ancestors.
    # Any third-party engine with unconventional naming (engine class IS the
    # module, not a nested ::Engine) crashed at boot when it called routes.draw.
    class DrawNilEngineTest < Minitest::Test
      def build_nil_engine_route_set
        route_set = ActionDispatch::Routing::RouteSet.new
        route_set.define_singleton_method(:default_scope) { {module: "dummy_gem_for_draw_test/dashboard"} }
        route_set
      end

      # The original crash: #draw called supported_engine?(nil), which raised
      # NoMethodError: undefined method `ancestors' for nil. After the fix, #draw
      # skips Plutonium handling for a nil engine and delegates to super quietly.
      def test_draw_does_not_raise_for_nil_engine
        route_set = build_nil_engine_route_set

        assert_silent { route_set.draw {} }
      end

      # #draw must still yield the block through super for a non-Plutonium engine
      # -- i.e. it delegates to real route drawing rather than swallowing it.
      # Guards against a future "fix" that returns early on nil without calling
      # super, which would silently drop the foreign engine's routes.
      def test_draw_delegates_to_super_for_nil_engine
        route_set = build_nil_engine_route_set
        block_called = false

        route_set.draw { block_called = true }

        assert block_called, "#draw must yield the block via super for a non-Plutonium engine"
      end
    end
  end
end

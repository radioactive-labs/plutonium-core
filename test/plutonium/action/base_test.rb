# file: /Users/stefan/code/plutonium/starters/vulcan/gems/plutonium/test/plutonium/action/base_test.rb

require "test_helper"

module Plutonium
  module Action
    class BaseTest < Minitest::Test
      def setup
        @action = Base.new(
          :test_action,
          label: "Test Action",
          icon: "test-icon",
          color: :blue,
          confirmation: "Are you sure?",
          route_options: RouteOptions.new(action: :test, method: :post),
          turbo_frame: "test_frame",
          collection_action: true,
          category: :test_category,
          position: 10
        )
      end

      def test_initialization
        assert_equal :test_action, @action.name
        assert_equal "Test Action", @action.label
        assert_equal "test-icon", @action.icon
        assert_equal :blue, @action.color
        assert_equal "Are you sure?", @action.confirmation
        assert_instance_of RouteOptions, @action.route_options
        assert_equal "test_frame", @action.turbo_frame
        assert_equal :test_category, @action.category
        assert_equal 10, @action.position
      end

      def test_default_values
        action = Base.new(:default_action)
        assert_equal "Default action", action.label
        assert_nil action.icon
        assert_nil action.color
        assert_nil action.confirmation
        assert_instance_of RouteOptions, action.route_options
        assert_nil action.turbo_frame
        assert_equal 50, action.position
      end

      def test_action_types
        assert @action.collection_action?
        refute @action.collection_record_action?
        refute @action.record_action?
        refute @action.global_action?

        global_action = Base.new(:global, global_action: true)
        assert global_action.global_action?
      end

      def test_frozen_instance
        assert @action.frozen?
      end

      def test_name_symbol_conversion
        action = Base.new("string_name")
        assert_equal :string_name, action.name
      end

      def test_label_fallback_to_humanized_name
        action = Base.new(:test_action_name)
        assert_equal "Test action name", action.label
      end

      def test_multiple_action_types
        action = Base.new(:multi, collection_action: true, record_action: true)
        assert action.collection_action?
        assert action.record_action?
        refute action.global_action?
        refute action.collection_record_action?
      end

      def test_immutability
        assert_raises(FrozenError) { @action.instance_variable_set(:@name, :new_name) }
      end

      def test_route_options_as_hash
        action = Base.new(:hash_route,
          route_options: {method: :put, action: :custom, key: "value"})
        assert_instance_of RouteOptions, action.route_options
        assert_equal :put, action.route_options.method
        assert_equal({action: :custom, key: "value"}, action.route_options.url_options)
      end

      def test_route_options_as_route_options_object
        route_options = RouteOptions.new(action: :predefined, method: :patch)
        action = Base.new(:object_route, route_options: route_options)
        assert_equal route_options, action.route_options
      end

      def test_route_options_default
        action = Base.new(:default_route)
        assert_instance_of RouteOptions, action.route_options
        assert_equal RouteOptions.new, action.route_options
      end

      def test_route_options_invalid_input
        assert_raises(ArgumentError) do
          Base.new(:invalid_route, route_options: "invalid")
        end
      end
    end
  end
end

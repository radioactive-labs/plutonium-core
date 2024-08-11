# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Action
    class RouteOptionsTest < Minitest::Test
      def setup
        @route_options = RouteOptions.new(
          :resources,
          :id,
          method: :post,
          action: :test_action,
          key: "value"
        )
      end

      def test_initialization
        assert_equal :post, @route_options.method
        assert_equal [:resources, :id], @route_options.url_args
        assert_equal({action: :test_action, key: "value"}, @route_options.url_options)
        assert_equal :resource_url_for, @route_options.url_resolver
      end

      def test_default_values
        default_options = RouteOptions.new
        assert_equal :get, default_options.method
        assert_empty default_options.url_args
        assert_empty default_options.url_options
        assert_equal :resource_url_for, default_options.url_resolver
      end

      def test_to_url_args
        expected = [:resources, :id, {action: :test_action, key: "value"}]
        assert_equal expected, @route_options.to_url_args
      end

      def test_merge
        other_options = RouteOptions.new(
          :other_resource,
          method: :put,
          action: :other_action,
          other_key: "other_value"
        )

        merged = @route_options.merge(other_options)

        assert_equal :put, merged.method
        assert_equal [:resources, :id, :other_resource], merged.url_args
        assert_equal({action: :other_action, key: "value", other_key: "other_value"}, merged.url_options)
      end

      def test_merge_with_empty_route_options
        empty_options = RouteOptions.new method: nil
        merged = @route_options.merge(empty_options)

        assert_equal @route_options.method, merged.method
        assert_equal @route_options.url_args, merged.url_args
        assert_equal @route_options.url_options, merged.url_options
      end

      def test_merge_preserves_original
        other_options = RouteOptions.new(action: :other_action)
        @route_options.merge(other_options)

        assert_equal :test_action, @route_options.url_options[:action]
      end

      def test_frozen_instance
        assert @route_options.frozen?
        assert @route_options.url_options.frozen?
      end

      def test_equality
        identical_options = RouteOptions.new(
          :resources,
          :id,
          method: :post,
          action: :test_action,
          key: "value"
        )
        assert_equal @route_options, identical_options

        different_options = RouteOptions.new(
          :resources,
          method: :get,
          action: :other_action
        )
        refute_equal @route_options, different_options
      end

      def test_hash
        identical_options = RouteOptions.new(
          :resources,
          :id,
          method: :post,
          action: :test_action,
          key: "value"
        )
        assert_equal @route_options.hash, identical_options.hash

        different_options = RouteOptions.new(
          :resources,
          method: :get,
          action: :other_action
        )
        refute_equal @route_options.hash, different_options.hash
      end

      def test_immutability
        assert_raises(FrozenError) { @route_options.url_options[:new_key] = "new_value" }
      end
    end
  end
end

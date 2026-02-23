# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Routing
    class RecordRoutesTest < Minitest::Test
      # Test using actual models from the dummy app
      def test_has_many_association_routes_on_real_model
        # Blogging::Post has_many :comments
        routes = Blogging::Post.has_many_association_routes

        # The plural name includes the namespace
        assert_includes routes, "blogging_comments"
      end

      def test_has_one_association_routes_on_real_model
        # Blogging::Post has_one :post_metadata
        routes = Blogging::Post.has_one_association_routes

        assert_includes routes, "blogging_post_metadata"
      end
    end

    class NestedRoutesTest < Minitest::Test
      def setup
        @parent_model = create_mock_model("User", "users")
        @has_many_model = create_mock_model("Post", "posts")
        @has_one_model = create_mock_model("Profile", "profiles")

        setup_associations(@parent_model, @has_many_model, @has_one_model)
      end

      # Test has_one_association_routes method
      def test_has_one_association_routes_returns_plural_names
        routes = @parent_model.has_one_association_routes

        assert_includes routes, "profiles"
        refute_includes routes, "posts"
      end

      def test_has_one_association_routes_excludes_through_associations
        # Create a model with only a has_one :through association
        parent_with_through = create_mock_model("Account", "accounts")
        through_assoc = Struct.new(:klass, :options).new(@has_one_model, {through: :posts})
        parent_with_through.has_one_assocs = [through_assoc]

        routes = parent_with_through.has_one_association_routes
        assert_empty routes
      end

      def test_has_many_association_routes_returns_plural_names
        routes = @parent_model.has_many_association_routes

        assert_includes routes, "posts"
        refute_includes routes, "profiles"
      end

      # Test route config lookup with nested keys
      def test_nested_route_config_uses_composite_key
        route_set = create_mock_route_set

        # Simulate registering a nested config
        nested_key = "users/profiles"
        config = {route_type: :resource, route_name: "profiles"}
        route_set.resource_route_config_lookup[nested_key] = config

        # Should be retrievable via resource_route_config_for
        result = route_set.resource_route_config_for(nested_key)
        assert_equal [config], result
      end

      def test_top_level_and_nested_configs_coexist
        route_set = create_mock_route_set

        # Register top-level config
        top_level_config = {route_type: :resources, route_name: "profiles"}
        route_set.resource_route_config_lookup["profiles"] = top_level_config

        # Register nested config with different route_type
        nested_config = {route_type: :resource, route_name: "profiles"}
        route_set.resource_route_config_lookup["users/profiles"] = nested_config

        # Both should be retrievable
        assert_equal :resources, route_set.resource_route_config_for("profiles")[0][:route_type]
        assert_equal :resource, route_set.resource_route_config_for("users/profiles")[0][:route_type]
      end

      def test_has_one_nested_config_has_resource_route_type
        route_set = create_mock_route_set

        # Simulate what mapper_extensions does for has_one
        original_config = {route_type: :resources, route_name: "profiles", route_options: {}}
        nested_config = original_config.merge(route_type: :resource)

        route_set.resource_route_config_lookup["users/profiles"] = nested_config

        result = route_set.resource_route_config_for("users/profiles")[0]
        assert_equal :resource, result[:route_type]
      end

      private

      def create_mock_model(name, plural)
        model = Class.new do
          class << self
            attr_accessor :model_name_value, :has_many_assocs, :has_one_assocs
          end

          def self.model_name
            model_name_value
          end

          def self.reflect_on_all_associations(type)
            case type
            when :has_many then has_many_assocs || []
            when :has_one then has_one_assocs || []
            else []
            end
          end

          def self.has_many_association_routes
            return @has_many_association_routes if defined?(@has_many_association_routes)

            @has_many_association_routes = reflect_on_all_associations(:has_many)
              .map { |assoc| assoc.klass.model_name.plural }
          end

          def self.has_one_association_routes
            return @has_one_association_routes if defined?(@has_one_association_routes)

            @has_one_association_routes = reflect_on_all_associations(:has_one)
              .reject { |assoc| assoc.options[:through] }
              .map { |assoc| assoc.klass.model_name.plural }
          end
        end

        model_name = Struct.new(:singular, :plural, :collection).new(
          name.downcase,
          plural,
          plural
        )
        model.model_name_value = model_name

        model
      end

      def setup_associations(parent, has_many_model, has_one_model)
        has_many_assoc = Struct.new(:klass, :options).new(has_many_model, {})
        has_one_assoc = Struct.new(:klass, :options).new(has_one_model, {})

        parent.has_many_assocs = [has_many_assoc]
        parent.has_one_assocs = [has_one_assoc]
      end

      def create_mock_route_set
        route_set = Object.new

        route_set.define_singleton_method(:resource_route_config_lookup) do
          @resource_route_config_lookup ||= {}
        end

        route_set.define_singleton_method(:resource_route_config_for) do |*routes|
          routes = Array(routes)
          resource_route_config_lookup.slice(*routes).values
        end

        route_set
      end
    end

    class RouteSetExtensionsTest < Minitest::Test
      def setup
        # Ensure routes are loaded so configs are populated
        Rails.application.reload_routes!
      end

      # entity_scope_params_for_path_strategy tests using real engines

      def test_entity_scope_params_for_path_strategy_returns_nil_when_not_path_scoped
        # DemoPortal has no entity scoping
        result = DemoPortal::Engine.routes.entity_scope_params_for_path_strategy

        assert_nil result
      end

      def test_entity_scope_params_for_path_strategy_returns_params_when_path_scoped
        # OrgPortal has path-based entity scoping with Organization
        result = OrgPortal::Engine.routes.entity_scope_params_for_path_strategy

        assert_equal ":organization", result[:name]
        assert_equal({as: :organization}, result[:options])
      end

      # singular_resource_route? tests using real engine routes

      def test_singular_resource_route_returns_true_for_nested_has_one
        # Blogging::Post has_one :post_metadata, registered as singular nested route
        assert DemoPortal::Engine.routes.singular_resource_route?("blogging_posts/post_metadata")
      end

      def test_singular_resource_route_returns_false_for_nested_has_many
        # Blogging::Post has_many :comments, registered as plural nested route
        refute DemoPortal::Engine.routes.singular_resource_route?("blogging_posts/comments")
      end

      def test_singular_resource_route_returns_false_for_top_level_plural_resources
        # Blogging::Post is registered as :resources (plural)
        refute DemoPortal::Engine.routes.singular_resource_route?("blogging_posts")
      end

      def test_singular_resource_route_returns_false_for_unregistered_resources
        refute DemoPortal::Engine.routes.singular_resource_route?("unknown_resources")
      end

      # Verify route type in config

      def test_has_one_nested_route_config_has_resource_type
        config = DemoPortal::Engine.routes.resource_route_config_for("blogging_posts/post_metadata")[0]

        assert_equal :resource, config[:route_type]
        assert_equal :post_metadata, config[:association_name]
      end

      def test_has_many_nested_route_config_has_resources_type
        config = DemoPortal::Engine.routes.resource_route_config_for("blogging_posts/comments")[0]

        assert_equal :resources, config[:route_type]
        assert_equal :comments, config[:association_name]
      end
    end
  end
end

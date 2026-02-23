# frozen_string_literal: true

require "test_helper"

class Plutonium::Helpers::DisplayHelperTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "display_helper_test@example.com", status: :verified)
    @post = Blogging::Post.create!(user: @user, title: "Test Post", body: "Body content")
  end

  teardown do
    Blogging::Post.delete_all
    User.delete_all
  end

  test "resource_label returns plural for resources routes" do
    get "/demo/blogging/posts"

    # Blogging::Post is registered as :resources (plural)
    label = controller.view_context.resource_label(Blogging::Post)

    assert_equal Blogging::Post.model_name.human.pluralize(2), label
  end

  test "resource_label returns singular for resource routes" do
    get "/demo/blogging/posts/#{@post.id}"

    # Mock a singular resource route configuration
    routes = DemoPortal::Engine.routes
    original_lookup = routes.resource_route_config_lookup.dup

    # Temporarily add a singular config for testing
    routes.resource_route_config_lookup["blogging_post_metadata"] = {
      route_type: :resource,
      route_name: "blogging_post_metadata"
    }

    begin
      label = controller.view_context.resource_label(Blogging::PostMetadata)
      assert_equal Blogging::PostMetadata.model_name.human.pluralize(1), label
    ensure
      # Restore original lookup
      routes.instance_variable_set(:@resource_route_config_lookup, original_lookup)
    end
  end

  test "resource_label falls back to plural when route config not found" do
    get "/demo/blogging/posts"

    # Create a mock class that isn't registered
    mock_class = Class.new do
      def self.model_name
        ActiveModel::Name.new(self, nil, "UnregisteredResource")
      end
    end

    label = controller.view_context.resource_label(mock_class)

    # Should default to plural (count 2) when config is nil
    assert_equal "Unregistered resources", label
  end

  # Note: singular_resource_route? tests are in nested_routes_test.rb
end

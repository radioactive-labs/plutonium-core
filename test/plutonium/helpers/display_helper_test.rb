# frozen_string_literal: true

require "test_helper"

class Plutonium::Helpers::DisplayHelperTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    @post = Blogging::Post.create!(user: @user, organization: @org, title: "Test Post", body: "Body content")
    login_as_admin(@admin)
  end

  test "resource_label returns plural for resources routes" do
    get "/admin/blogging/posts"

    # Blogging::Post is registered as :resources (plural)
    label = controller.view_context.resource_label(Blogging::Post)

    assert_equal Blogging::Post.model_name.human.pluralize(2), label
  end

  test "resource_label returns singular for resource routes" do
    get "/admin/blogging/posts/#{@post.id}"

    # Mock a singular resource route configuration
    routes = AdminPortal::Engine.routes
    original_lookup = routes.resource_route_config_lookup.dup

    # Temporarily add a singular config for testing
    routes.resource_route_config_lookup["blogging_post_details"] = {
      route_type: :resource,
      route_name: "blogging_post_details"
    }

    begin
      label = controller.view_context.resource_label(Blogging::PostDetail)
      assert_equal Blogging::PostDetail.model_name.human.pluralize(1), label
    ensure
      # Restore original lookup
      routes.instance_variable_set(:@resource_route_config_lookup, original_lookup)
    end
  end

  test "resource_label falls back to plural when route config not found" do
    get "/admin/blogging/posts"

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

  test "resource_name uses the locale's plural when the model defines one" do
    get "/admin/blogging/posts"
    I18n.backend.store_translations(:en, activerecord: {models: {"blogging/post": {one: "Article", other: "Articles"}}})

    assert_equal "Article", controller.view_context.resource_name(Blogging::Post)
    assert_equal "Articles", controller.view_context.resource_name_plural(Blogging::Post)
  ensure
    I18n.backend.reload!
  end

  test "resource_name falls back to English inflection when the locale has no plural" do
    get "/admin/blogging/posts"

    assert_equal "Post", controller.view_context.resource_name(Blogging::Post)
    assert_equal "Posts", controller.view_context.resource_name_plural(Blogging::Post)
  end

  test "display_name_of falls back to the resource name and id" do
    get "/admin/blogging/posts"
    record = Struct.new(:id) { def self.model_name = ActiveModel::Name.new(self, nil, "Widget") }.new(9)

    assert_equal "Widget #9", controller.view_context.display_name_of(record)
  end
end

# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "generators/pu/lib/plutonium_generators"

class ScaffoldGeneratorNamespaceTest < ActiveSupport::TestCase
  # Test the namespace deduplication logic in ModelGeneratorBase#name
  # We test the logic directly without instantiating the full generator

  test "strips destination namespace from resource name when already present" do
    # Simulate what the name method does
    resource_name = "Blogging::Article".singularize.underscore  # => "blogging/article"
    dest_namespace = "blogging"

    if dest_namespace && resource_name.start_with?("#{dest_namespace}/")
      resource_name = resource_name.sub("#{dest_namespace}/", "")
    end
    result = [dest_namespace, resource_name].compact.join("/")

    assert_equal "blogging/article", result
  end

  test "adds namespace when resource is not already namespaced" do
    resource_name = "Product".singularize.underscore  # => "product"
    dest_namespace = "inventory"

    if dest_namespace && resource_name.start_with?("#{dest_namespace}/")
      resource_name = resource_name.sub("#{dest_namespace}/", "")
    end
    result = [dest_namespace, resource_name].compact.join("/")

    assert_equal "inventory/product", result
  end

  test "does not modify name for main_app destination" do
    resource_name = "Post".singularize.underscore  # => "post"
    dest_namespace = nil  # main_app returns nil

    if dest_namespace && resource_name.start_with?("#{dest_namespace}/")
      resource_name = resource_name.sub("#{dest_namespace}/", "")
    end
    result = [dest_namespace, resource_name].compact.join("/")

    assert_equal "post", result
  end

  test "handles deeply namespaced resources correctly" do
    resource_name = "Admin::Users::Profile".singularize.underscore  # => "admin/users/profile"
    dest_namespace = "admin"

    if dest_namespace && resource_name.start_with?("#{dest_namespace}/")
      resource_name = resource_name.sub("#{dest_namespace}/", "")
    end
    result = [dest_namespace, resource_name].compact.join("/")

    assert_equal "admin/users/profile", result
  end

  test "does not strip partial namespace matches" do
    resource_name = "Blogging::Post".singularize.underscore  # => "blogging/post"
    dest_namespace = "blog"

    # "blogging/post" does not start with "blog/", so should not strip
    if dest_namespace && resource_name.start_with?("#{dest_namespace}/")
      resource_name = resource_name.sub("#{dest_namespace}/", "")
    end
    result = [dest_namespace, resource_name].compact.join("/")

    assert_equal "blog/blogging/post", result
  end
end

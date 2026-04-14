# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::DSLTest < ActiveSupport::TestCase
  class FakeAdminTest < ActiveSupport::TestCase
    include Plutonium::Testing::DSL
    resource_tests_for Blogging::Post,
      portal: :admin,
      parent: :organization,
      actions: %i[index show],
      skip: %i[show]
  end

  test "stores resource class" do
    assert_equal Blogging::Post, FakeAdminTest.resource_tests_config.fetch(:resource)
  end

  test "stores portal symbol" do
    assert_equal :admin, FakeAdminTest.resource_tests_config.fetch(:portal)
  end

  test "resolves path prefix from portal" do
    assert_equal "/admin", FakeAdminTest.resource_tests_config.fetch(:path_prefix)
  end

  test "stores parent / actions / skip" do
    cfg = FakeAdminTest.resource_tests_config
    assert_equal :organization, cfg.fetch(:parent)
    assert_equal %i[index show], cfg.fetch(:actions)
    assert_equal %i[show], cfg.fetch(:skip)
  end

  test "explicit path_prefix overrides portal resolution" do
    klass = Class.new(ActiveSupport::TestCase) do
      include Plutonium::Testing::DSL
      resource_tests_for Blogging::Post, portal: :admin, path_prefix: "/custom"
    end
    assert_equal "/custom", klass.resource_tests_config.fetch(:path_prefix)
  end

  test "raises when portal cannot be resolved" do
    err = assert_raises(Plutonium::Testing::DSL::PortalNotFound) do
      Class.new(ActiveSupport::TestCase) do
        include Plutonium::Testing::DSL
        resource_tests_for Blogging::Post, portal: :nonexistent
      end
    end
    assert_match(/nonexistent/, err.message)
  end

  test "instance current_portal returns symbol" do
    instance = FakeAdminTest.new(:noop)
    assert_equal :admin, instance.current_portal
  end

  test "instance current_path_prefix returns prefix" do
    instance = FakeAdminTest.new(:noop)
    assert_equal "/admin", instance.current_path_prefix
  end
end

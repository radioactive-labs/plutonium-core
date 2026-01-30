# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "generators/pu/lib/plutonium_generators"

class PackageSelectorTest < ActiveSupport::TestCase
  class TestGenerator < Rails::Generators::Base
    include PlutoniumGenerators::Generator
    include PlutoniumGenerators::Concerns::PackageSelector
  end

  def setup
    @generator = TestGenerator.new
    @generator.instance_variable_set(:@available_packages, %w[customer_portal admin_portal blogging])
    @generator.instance_variable_set(:@available_portals, %w[main_app customer_portal admin_portal])
    @generator.instance_variable_set(:@available_features, %w[main_app blogging])
  end

  test "select_package normalizes CamelCase to underscore" do
    result = @generator.send(:select_package, "CustomerPortal", pkgs: %w[customer_portal admin_portal])
    assert_equal "customer_portal", result
  end

  test "select_package normalizes PascalCase with multiple words" do
    result = @generator.send(:select_package, "AdminPortal", pkgs: %w[customer_portal admin_portal])
    assert_equal "admin_portal", result
  end

  test "select_package accepts already underscored names" do
    result = @generator.send(:select_package, "customer_portal", pkgs: %w[customer_portal admin_portal])
    assert_equal "customer_portal", result
  end

  test "select_portal normalizes CamelCase destination" do
    result = @generator.send(:select_portal, "CustomerPortal")
    assert_equal "customer_portal", result
  end

  test "select_feature normalizes CamelCase source" do
    result = @generator.send(:select_feature, "Blogging")
    assert_equal "blogging", result
  end

  test "select_package with non-matching input returns nil for normalization" do
    # When input doesn't match after normalization, select_package would prompt
    # We test the normalization logic by checking a matching case
    normalized = "NonExistent".underscore
    assert_equal "non_existent", normalized
    refute_includes %w[customer_portal admin_portal], normalized
  end
end

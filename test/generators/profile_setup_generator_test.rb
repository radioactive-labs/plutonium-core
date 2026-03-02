# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/profile/setup_generator"

class ProfileSetupGeneratorTest < ActiveSupport::TestCase
  # Test the generator class definition and options

  test "generator has user_model option with default" do
    opt = Pu::Profile::SetupGenerator.class_options[:user_model]
    assert opt
    assert_equal "User", opt.default
  end

  test "generator has dest option without default" do
    opt = Pu::Profile::SetupGenerator.class_options[:dest]
    assert opt
    assert_nil opt.default
  end

  test "generator has portal option" do
    opt = Pu::Profile::SetupGenerator.class_options[:portal]
    assert opt
  end

  test "normalize_arguments treats colon-containing name as attribute" do
    generator = build_generator(["bio:text", "avatar:attachment"])
    generator.normalize_arguments

    assert_equal "Profile", generator.instance_variable_get(:@profile_name)
    assert_equal ["bio:text", "avatar:attachment"], generator.instance_variable_get(:@profile_attributes)
  end

  test "normalize_arguments uses explicit name when provided" do
    generator = build_generator(["AccountSettings", "bio:text"])
    generator.normalize_arguments

    assert_equal "AccountSettings", generator.instance_variable_get(:@profile_name)
    assert_equal ["bio:text"], generator.instance_variable_get(:@profile_attributes)
  end

  test "resource_class_name for main_app" do
    generator = build_generator([], dest: "main_app")
    generator.normalize_arguments
    generator.define_singleton_method(:selected_destination_feature) { "main_app" }

    assert_equal "Profile", generator.send(:resource_class_name)
  end

  test "resource_class_name for package" do
    generator = build_generator([], dest: "customer")
    generator.normalize_arguments
    generator.define_singleton_method(:selected_destination_feature) { "customer" }

    assert_equal "Customer::Profile", generator.send(:resource_class_name)
  end

  test "resource_class_name with custom name for package" do
    generator = build_generator(["AccountSettings"], dest: "customer")
    generator.normalize_arguments
    generator.define_singleton_method(:selected_destination_feature) { "customer" }

    assert_equal "Customer::AccountSettings", generator.send(:resource_class_name)
  end

  test "dest_package? returns false for main_app" do
    generator = build_generator([], dest: "main_app")
    generator.define_singleton_method(:selected_destination_feature) { "main_app" }

    refute generator.send(:dest_package?)
  end

  test "dest_package? returns true for packages" do
    generator = build_generator([], dest: "customer")
    generator.define_singleton_method(:selected_destination_feature) { "customer" }

    assert generator.send(:dest_package?)
  end

  private

  def build_generator(args, dest: nil, portal: nil)
    opts = {}
    opts[:dest] = dest if dest
    opts[:portal] = portal if portal

    Pu::Profile::SetupGenerator.new(
      args,
      opts,
      destination_root: Rails.root
    )
  end
end

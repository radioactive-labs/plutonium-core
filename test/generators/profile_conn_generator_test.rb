# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/profile/conn_generator"

class ProfileConnGeneratorTest < ActiveSupport::TestCase
  # Test the generator class definition and helper methods

  test "generator has dest option" do
    opt = Pu::Profile::ConnGenerator.class_options[:dest]
    assert opt
  end

  test "generator has user_model option with default" do
    opt = Pu::Profile::ConnGenerator.class_options[:user_model]
    assert opt
    assert_equal "User", opt.default
  end

  test "user_table underscores user_model option" do
    generator = build_generator("Profile", user_model: "User")
    assert_equal "user", generator.send(:user_table)

    generator = build_generator("Profile", user_model: "Account")
    assert_equal "account", generator.send(:user_table)

    generator = build_generator("Profile", user_model: "AdminUser")
    assert_equal "admin_user", generator.send(:user_table)
  end

  test "resource_class_name camelizes input" do
    generator = build_generator("profile")
    assert_equal "Profile", generator.send(:resource_class_name)

    generator = build_generator("account_settings")
    assert_equal "AccountSettings", generator.send(:resource_class_name)
  end

  test "profile_association demodulizes and underscores" do
    generator = build_generator("Profile")
    assert_equal "profile", generator.send(:profile_association)

    generator = build_generator("Competition::Profile")
    assert_equal "profile", generator.send(:profile_association)

    generator = build_generator("AccountSettings")
    assert_equal "account_settings", generator.send(:profile_association)
  end

  test "validate_portal_destination! raises for main_app" do
    generator = build_generator("Profile", dest: "main_app")
    generator.define_singleton_method(:selected_destination_portal) { "main_app" }

    error = assert_raises(ArgumentError) do
      generator.send(:validate_portal_destination!)
    end

    assert_includes error.message, "portal packages only"
    assert_includes error.message, "ResourceController"
  end

  test "validate_portal_destination! passes for portal packages" do
    generator = build_generator("Profile", dest: "customer_portal")
    generator.define_singleton_method(:selected_destination_portal) { "customer_portal" }

    # Should not raise
    assert_nothing_raised do
      generator.send(:validate_portal_destination!)
    end
  end

  test "controller_path for package" do
    generator = build_generator("Profile", dest: "customer_portal")
    generator.define_singleton_method(:selected_destination_portal) { "customer_portal" }

    assert_equal "packages/customer_portal/app/controllers/customer_portal/profiles_controller.rb",
      generator.send(:controller_path)
  end

  test "policy_path for package" do
    generator = build_generator("Profile", dest: "customer_portal")
    generator.define_singleton_method(:selected_destination_portal) { "customer_portal" }

    assert_equal "packages/customer_portal/app/policies/customer_portal/profile_policy.rb",
      generator.send(:policy_path)
  end

  test "definition_path for package" do
    generator = build_generator("Profile", dest: "customer_portal")
    generator.define_singleton_method(:selected_destination_portal) { "customer_portal" }

    assert_equal "packages/customer_portal/app/definitions/customer_portal/profile_definition.rb",
      generator.send(:definition_path)
  end

  test "concerns_controller_path for package" do
    generator = build_generator("Profile", dest: "customer_portal")
    generator.define_singleton_method(:selected_destination_portal) { "customer_portal" }

    assert_equal "packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb",
      generator.send(:concerns_controller_path)
  end

  test "paths handle namespaced resources" do
    generator = build_generator("Customer::Profile", dest: "customer_portal")
    generator.define_singleton_method(:selected_destination_portal) { "customer_portal" }

    assert_equal "packages/customer_portal/app/controllers/customer_portal/customer/profiles_controller.rb",
      generator.send(:controller_path)
    assert_equal "packages/customer_portal/app/policies/customer_portal/customer/profile_policy.rb",
      generator.send(:policy_path)
    assert_equal "packages/customer_portal/app/definitions/customer_portal/customer/profile_definition.rb",
      generator.send(:definition_path)
  end

  private

  def build_generator(name, dest: nil, user_model: nil)
    args = [name]
    opts = {}
    opts[:dest] = dest if dest
    opts[:user_model] = user_model if user_model

    Pu::Profile::ConnGenerator.new(
      args,
      opts,
      destination_root: Rails.root
    )
  end
end

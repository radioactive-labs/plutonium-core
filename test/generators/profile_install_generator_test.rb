# frozen_string_literal: true


require "test_helper"
require "rails/generators/test_case"
require "generators/pu/profile/install_generator"

class ProfileInstallGeneratorTest < ActiveSupport::TestCase
  # Test the generator class definition and options

  test "generator has user_model option with default" do
    opt = Pu::Profile::InstallGenerator.class_options[:user_model]
    assert opt
    assert_equal "User", opt.default
  end

  test "generator has dest option without default" do
    opt = Pu::Profile::InstallGenerator.class_options[:dest]
    assert opt
    assert_nil opt.default
  end

  test "normalize_arguments treats colon-containing name as attribute" do
    generator = Pu::Profile::InstallGenerator.new(
      ["bio:text", "avatar:attachment"],
      {dest: "main_app"},
      destination_root: Rails.root
    )
    generator.normalize_arguments

    assert_equal "Profile", generator.instance_variable_get(:@profile_name)
    assert_equal ["bio:text", "avatar:attachment"], generator.instance_variable_get(:@profile_attributes)
  end

  test "normalize_arguments uses explicit name when provided" do
    generator = Pu::Profile::InstallGenerator.new(
      ["AccountSettings", "bio:text"],
      {dest: "main_app"},
      destination_root: Rails.root
    )
    generator.normalize_arguments

    assert_equal "AccountSettings", generator.instance_variable_get(:@profile_name)
    assert_equal ["bio:text"], generator.instance_variable_get(:@profile_attributes)
  end

  test "scaffold_attributes includes user belongs_to" do
    generator = Pu::Profile::InstallGenerator.new(
      ["bio:text"],
      {dest: "main_app", user_model: "User"},
      destination_root: Rails.root
    )
    generator.normalize_arguments

    attributes = generator.send(:scaffold_attributes)
    assert_includes attributes, "user:belongs_to"
    assert_includes attributes, "bio:text"
  end

  test "scaffold_attributes uses custom user_model" do
    generator = Pu::Profile::InstallGenerator.new(
      [],
      {dest: "main_app", user_model: "Account"},
      destination_root: Rails.root
    )
    generator.normalize_arguments

    attributes = generator.send(:scaffold_attributes)
    assert_includes attributes, "account:belongs_to"
  end

  test "table_name for main_app" do
    generator = Pu::Profile::InstallGenerator.new(
      [],
      {dest: "main_app"},
      destination_root: Rails.root
    )
    generator.normalize_arguments

    assert_equal "profiles", generator.send(:table_name)
  end

  test "table_name for package includes prefix" do
    generator = build_generator_with_dest("customer")
    generator.normalize_arguments

    assert_equal "customer_profiles", generator.send(:table_name)
  end

  test "namespaced_class_name for main_app" do
    generator = Pu::Profile::InstallGenerator.new(
      [],
      {dest: "main_app"},
      destination_root: Rails.root
    )
    generator.normalize_arguments

    assert_equal "Profile", generator.send(:namespaced_class_name)
  end

  test "namespaced_class_name for package" do
    generator = build_generator_with_dest("customer")
    generator.normalize_arguments

    assert_equal "Customer::Profile", generator.send(:namespaced_class_name)
  end

  test "migration_dir for main_app" do
    generator = Pu::Profile::InstallGenerator.new(
      [],
      {dest: "main_app"},
      destination_root: Rails.root
    )

    assert_equal "db/migrate", generator.send(:migration_dir)
  end

  test "migration_dir for package" do
    generator = build_generator_with_dest("customer")

    assert_equal "packages/customer/db/migrate", generator.send(:migration_dir)
  end

  test "user_model_path" do
    generator = Pu::Profile::InstallGenerator.new(
      [],
      {dest: "main_app", user_model: "User"},
      destination_root: Rails.root
    )

    assert_equal "app/models/user.rb", generator.send(:user_model_path)
  end

  test "user_model_path with custom user_model" do
    generator = Pu::Profile::InstallGenerator.new(
      [],
      {dest: "main_app", user_model: "AdminUser"},
      destination_root: Rails.root
    )

    assert_equal "app/models/admin_user.rb", generator.send(:user_model_path)
  end

  private

  # Build a generator with a non-existent package destination.
  # Pre-sets the feature_option cache to bypass interactive prompt validation.
  def build_generator_with_dest(dest)
    generator = Pu::Profile::InstallGenerator.new(
      [],
      {dest: dest},
      destination_root: Rails.root
    )
    generator.instance_variable_set(:@dest_feature_option, dest)
    generator
  end
end

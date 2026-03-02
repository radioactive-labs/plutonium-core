# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/profile/concerns/profile_arguments"

class ProfileArgumentsConcernTest < ActiveSupport::TestCase
  # Create a test generator class that includes the concern
  class TestGenerator < ::Rails::Generators::Base
    include Pu::Profile::Concerns::ProfileArguments
  end

  test "concern adds name argument with default Profile" do
    arg = TestGenerator.arguments.find { |a| a.name == "name" }

    assert arg
    assert_equal "Profile", arg.default
    refute arg.required
  end

  test "concern adds attributes argument as array" do
    arg = TestGenerator.arguments.find { |a| a.name == "attributes" }

    assert arg
    assert_equal :array, arg.type
    assert_equal [], arg.default
  end

  test "normalize_arguments with explicit name" do
    generator = TestGenerator.new(["AccountSettings", "bio:text", "avatar:attachment"])
    generator.normalize_arguments

    assert_equal "AccountSettings", generator.instance_variable_get(:@profile_name)
    assert_equal ["bio:text", "avatar:attachment"], generator.instance_variable_get(:@profile_attributes)
  end

  test "normalize_arguments treats colon-containing first arg as attribute" do
    generator = TestGenerator.new(["bio:text", "avatar:attachment"])
    generator.normalize_arguments

    assert_equal "Profile", generator.instance_variable_get(:@profile_name)
    assert_equal ["bio:text", "avatar:attachment"], generator.instance_variable_get(:@profile_attributes)
  end

  test "normalize_arguments with no arguments uses defaults" do
    generator = TestGenerator.new([])
    generator.normalize_arguments

    assert_equal "Profile", generator.instance_variable_get(:@profile_name)
    assert_equal [], generator.instance_variable_get(:@profile_attributes)
  end
end

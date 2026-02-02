# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators"

class LiteGeneratorsTest < ActiveSupport::TestCase
  def self.load_generators
    require "generators/pu/lite/setup/setup_generator"
    require "generators/pu/lite/solid_queue/solid_queue_generator"
    require "generators/pu/lite/solid_cache/solid_cache_generator"
    require "generators/pu/lite/solid_cable/solid_cable_generator"
    require "generators/pu/lite/solid_errors/solid_errors_generator"
    require "generators/pu/lite/litestream/litestream_generator"
  end

  load_generators
  # Test Setup Generator
  test "setup generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SetupGenerator)
    assert Pu::Lite::SetupGenerator < Rails::Generators::Base
  end

  test "setup generator includes PlutoniumGenerators::Generator" do
    assert Pu::Lite::SetupGenerator.include?(PlutoniumGenerators::Generator)
  end

  # Test Solid Queue Generator
  test "solid_queue generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidQueueGenerator)
    assert Pu::Lite::SolidQueueGenerator < Rails::Generators::Base
  end

  test "solid_queue generator has database option with default 'queue'" do
    options = Pu::Lite::SolidQueueGenerator.class_options
    assert options.key?(:database)
    assert_equal "queue", options[:database].default
  end

  test "solid_queue generator has route option with default '/manage/jobs'" do
    options = Pu::Lite::SolidQueueGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/jobs", options[:route].default
  end

  test "solid_queue generator has skip_mission_control option" do
    options = Pu::Lite::SolidQueueGenerator.class_options
    assert options.key?(:skip_mission_control)
    assert_equal false, options[:skip_mission_control].default
  end

  # Test Solid Cache Generator
  test "solid_cache generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidCacheGenerator)
  end

  test "solid_cache generator has database option with default 'cache'" do
    options = Pu::Lite::SolidCacheGenerator.class_options
    assert options.key?(:database)
    assert_equal "cache", options[:database].default
  end

  test "solid_cache generator has dev_cache option" do
    options = Pu::Lite::SolidCacheGenerator.class_options
    assert options.key?(:dev_cache)
    assert_equal true, options[:dev_cache].default
  end

  # Test Solid Cable Generator
  test "solid_cable generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidCableGenerator)
  end

  test "solid_cable generator has database option with default 'cable'" do
    options = Pu::Lite::SolidCableGenerator.class_options
    assert options.key?(:database)
    assert_equal "cable", options[:database].default
  end

  # Test Solid Errors Generator
  test "solid_errors generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidErrorsGenerator)
  end

  test "solid_errors generator has database option with default 'errors'" do
    options = Pu::Lite::SolidErrorsGenerator.class_options
    assert options.key?(:database)
    assert_equal "errors", options[:database].default
  end

  test "solid_errors generator has route option with default '/manage/errors'" do
    options = Pu::Lite::SolidErrorsGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/errors", options[:route].default
  end

  # Test Litestream Generator
  test "litestream generator exists and has correct namespace" do
    assert defined?(Pu::Lite::LitestreamGenerator)
  end

  test "litestream generator has route option with default '/manage/litestream'" do
    options = Pu::Lite::LitestreamGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/litestream", options[:route].default
  end

  test "litestream generator has credentials option defaulting to true" do
    options = Pu::Lite::LitestreamGenerator.class_options
    assert options.key?(:credentials)
    assert_equal true, options[:credentials].default
  end

  # Test generators include appropriate concerns
  test "solid_queue generator includes ConfiguresSqlite and MountsEngines concerns" do
    assert Pu::Lite::SolidQueueGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
    assert Pu::Lite::SolidQueueGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end

  test "solid_cache generator includes ConfiguresSqlite concern" do
    assert Pu::Lite::SolidCacheGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
  end

  test "solid_cable generator includes ConfiguresSqlite concern" do
    assert Pu::Lite::SolidCableGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
  end

  test "solid_errors generator includes ConfiguresSqlite and MountsEngines concerns" do
    assert Pu::Lite::SolidErrorsGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
    assert Pu::Lite::SolidErrorsGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end

  test "litestream generator includes MountsEngines concern" do
    assert Pu::Lite::LitestreamGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end
end

# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators"
require "generators/pu/lite/rails_pulse/rails_pulse_generator"

class RailsPulseGeneratorTest < ActiveSupport::TestCase
  test "rails_pulse generator exists and has correct namespace" do
    assert defined?(Pu::Lite::RailsPulseGenerator)
    assert Pu::Lite::RailsPulseGenerator < Rails::Generators::Base
  end

  test "rails_pulse generator includes PlutoniumGenerators::Generator" do
    assert Pu::Lite::RailsPulseGenerator.include?(PlutoniumGenerators::Generator)
  end

  test "rails_pulse generator includes ConfiguresSqlite and MountsEngines concerns" do
    assert Pu::Lite::RailsPulseGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
    assert Pu::Lite::RailsPulseGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end

  test "rails_pulse generator has database option defaulting to 'rails_pulse'" do
    options = Pu::Lite::RailsPulseGenerator.class_options
    assert options.key?(:database)
    assert_equal "rails_pulse", options[:database].default
  end

  test "rails_pulse generator has route option with default '/manage/pulse'" do
    options = Pu::Lite::RailsPulseGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/pulse", options[:route].default
  end

  test "rails_pulse generator has source_root set" do
    assert Pu::Lite::RailsPulseGenerator.source_root.present?
    assert File.directory?(Pu::Lite::RailsPulseGenerator.source_root)
  end
end

class RailsPulseTemplateTest < ActiveSupport::TestCase
  TEMPLATE_PATH = File.expand_path(
    "../../lib/generators/pu/lite/rails_pulse/templates/config/initializers/rails_pulse.rb.tt",
    __dir__
  )

  def setup
    @template_content = File.read(TEMPLATE_PATH)
  end

  test "template exists" do
    assert File.exist?(TEMPLATE_PATH)
  end

  test "template includes RailsPulse.configure block" do
    assert_match(/RailsPulse\.configure do \|config\|/, @template_content)
  end

  test "template includes enabled configuration" do
    assert_match(/config\.enabled/, @template_content)
  end

  test "template includes track_assets configuration" do
    assert_match(/config\.track_assets/, @template_content)
  end

  test "template has conditional database configuration" do
    assert_match(/if options\[:database\]/, @template_content)
    assert_match(/config\.connects_to/, @template_content)
  end
end

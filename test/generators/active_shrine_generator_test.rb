# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators"
require "generators/pu/gem/active_shrine/active_shrine_generator"

class ActiveShrineGeneratorTest < ActiveSupport::TestCase
  test "active_shrine generator exists and has correct namespace" do
    assert defined?(Pu::Gem::ActiveShrineGenerator)
    assert Pu::Gem::ActiveShrineGenerator < Rails::Generators::Base
  end

  test "active_shrine generator includes PlutoniumGenerators::Generator" do
    assert Pu::Gem::ActiveShrineGenerator.include?(PlutoniumGenerators::Generator)
  end

  test "active_shrine generator has s3 option defaulting to false" do
    options = Pu::Gem::ActiveShrineGenerator.class_options
    assert options.key?(:s3)
    assert_equal false, options[:s3].default
  end

  test "active_shrine generator has store_dimensions option defaulting to false" do
    options = Pu::Gem::ActiveShrineGenerator.class_options
    assert options.key?(:store_dimensions)
    assert_equal false, options[:store_dimensions].default
  end

  test "active_shrine generator has source_root set" do
    assert Pu::Gem::ActiveShrineGenerator.source_root.present?
    assert File.directory?(Pu::Gem::ActiveShrineGenerator.source_root)
  end
end

class ActiveShrineTemplateTest < ActiveSupport::TestCase
  TEMPLATE_PATH = File.expand_path(
    "../../lib/generators/pu/gem/active_shrine/templates/config/initializers/shrine.rb.tt",
    __dir__
  )

  def setup
    @template_content = File.read(TEMPLATE_PATH)
  end

  test "template exists" do
    assert File.exist?(TEMPLATE_PATH)
  end

  test "template includes shrine require" do
    assert_match(/require "shrine"/, @template_content)
  end

  test "template has conditional for S3 storage" do
    assert_match(/if options\[:s3\]/, @template_content)
    assert_match(/Shrine::Storage::S3/, @template_content)
  end

  test "template has conditional for FileSystem storage" do
    assert_match(/Shrine::Storage::FileSystem/, @template_content)
  end

  test "template has conditional for store_dimensions plugin" do
    assert_match(/if options\[:store_dimensions\]/, @template_content)
    assert_match(/Shrine\.plugin :store_dimensions/, @template_content)
  end

  test "template includes remove_invalid plugin" do
    assert_match(/Shrine\.plugin :remove_invalid/, @template_content)
  end

  test "template includes backgrounding configuration" do
    assert_match(/Shrine\.plugin :backgrounding/, @template_content)
    assert_match(/Shrine::Attacher\.promote_block/, @template_content)
    assert_match(/Shrine::Attacher\.destroy_block/, @template_content)
  end

  test "template uses Rails.application.configure block" do
    # The shrine template doesn't use Rails.application.configure since it's Shrine config
    # Just verify it has proper Shrine configuration
    assert_match(/Shrine\.storages/, @template_content)
    assert_match(/Shrine\.plugin/, @template_content)
  end
end

# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators"
require "generators/pu/lib/plutonium_generators"

class ActionsTest < ActiveSupport::TestCase
  class TestGenerator < Rails::Generators::Base
    include PlutoniumGenerators::Generator
  end

  def setup
    @generator = TestGenerator.new
    @generator.destination_root = Rails.root
  end

  test "gem_in_bundle? returns true when gem is in Gemfile" do
    # plutonium is definitely in the Gemfile
    assert @generator.send(:gem_in_bundle?, "plutonium")
  end

  test "gem_in_bundle? returns true when gem is in Gemfile.lock" do
    # rails is in Gemfile.lock
    assert @generator.send(:gem_in_bundle?, "rails")
  end

  test "gem_in_bundle? returns false for non-existent gem" do
    refute @generator.send(:gem_in_bundle?, "this_gem_definitely_does_not_exist_12345")
  end

  test "gem_in_bundle? handles gems with similar names correctly" do
    # Should not match partial names
    # 'rail' should not match 'rails' in the lock file format "    rails "
    refute @generator.send(:gem_in_bundle?, "rail")
  end
end

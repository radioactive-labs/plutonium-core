# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/test/install/install_generator"

class TestInstallGeneratorTest < Rails::Generators::TestCase
  tests Pu::Test::InstallGenerator
  destination File.expand_path("../../tmp/pu_test_install", __dir__)
  setup :prepare_destination

  setup do
    FileUtils.mkdir_p(File.join(destination_root, "test"))
    File.write(File.join(destination_root, "test/test_helper.rb"), "ENV['RAILS_ENV'] ||= 'test'\n")
  end

  test "adds require to test_helper.rb" do
    run_generator
    helper = File.read(File.join(destination_root, "test/test_helper.rb"))
    assert_includes helper, %(require "plutonium/testing")
  end

  test "is idempotent" do
    run_generator
    run_generator
    helper = File.read(File.join(destination_root, "test/test_helper.rb"))
    assert_equal 1, helper.scan(%(require "plutonium/testing")).size
  end

  test "creates support file with override stub" do
    run_generator
    assert_file "test/support/plutonium_testing.rb" do |content|
      assert_match(/sign_in_for_tests/, content)
    end
  end
end

# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/saas/entity_generator"

class SaasEntityGeneratorTest < Rails::Generators::TestCase
  tests Pu::Saas::EntityGenerator
  destination Rails.root

  def teardown
    cleanup_generated_files("test_org")
  end

  test "generates entity model with name attribute" do
    run_generator ["TestOrg", "--dest=main_app"]

    assert_file "app/models/test_org.rb" do |content|
      assert_match(/class TestOrg/, content)
    end
  end

  test "generates controller, policy, and definition" do
    run_generator ["TestOrg", "--dest=main_app"]

    assert_file "app/controllers/test_orgs_controller.rb"
    assert_file "app/policies/test_org_policy.rb"
    assert_file "app/definitions/test_org_definition.rb"
  end

  test "accepts extra_attributes option without error" do
    assert_nothing_raised do
      run_generator ["TestOrg", "--dest=main_app", "--extra-attributes=slug:string"]
    end

    assert_file "app/models/test_org.rb"
  end

  private

  def cleanup_generated_files(name)
    normalized = name.underscore
    files = [
      "app/models/#{normalized}.rb",
      "app/definitions/#{normalized}_definition.rb",
      "app/policies/#{normalized}_policy.rb",
      "app/controllers/#{normalized.pluralize}_controller.rb"
    ]

    files.each { |f| FileUtils.rm_rf(destination_root.join(f)) }

    Dir.glob(destination_root.join("db/migrate/*#{normalized}*.rb")).each do |f|
      FileUtils.rm(f)
    end
  end
end

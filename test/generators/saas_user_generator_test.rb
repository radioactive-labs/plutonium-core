# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/saas/user_generator"

class SaasUserGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Saas::UserGenerator
  destination Rails.root

  def setup
    git_ensure_clean_dummy_app
  end

  test "generates user account with rodauth plugin" do
    run_generator ["TestUser"]

    assert_file "app/models/test_user.rb" do |content|
      assert_match(/class TestUser < ResourceRecord/, content)
      assert_match(/include Rodauth::Rails\.model\(:test_user\)/, content)
    end

    assert_file "app/rodauth/test_user_rodauth_plugin.rb" do |content|
      assert_match(/accounts_table :test_users/, content)
    end
  end

  test "generates user with allow_signup enabled by default" do
    run_generator ["TestUser"]

    assert_file "app/rodauth/test_user_rodauth_plugin.rb" do |content|
      assert_match(/:create_account/, content)
    end
  end

  test "generates user with allow_signup disabled" do
    run_generator ["TestUser", "--no-allow-signup"]

    assert_file "app/rodauth/test_user_rodauth_plugin.rb" do |content|
      refute_match(/:create_account/, content)
    end
  end

  test "adds extra_attributes to migration" do
    run_generator ["TestUser", "--extra-attributes", "name:string", "phone:string?"]

    assert_file "app/models/test_user.rb"

    # Find the migration file and verify extra columns are present
    migration_files = Dir[destination_root.join("db/migrate/*_test_user*.rb")]
    assert migration_files.any?, "Migration file should exist"

    migration_content = File.read(migration_files.first)
    assert_match(/t\.string :name/, migration_content, "Migration should include name column")
    assert_match(/t\.string :phone/, migration_content, "Migration should include phone column")
  end
end

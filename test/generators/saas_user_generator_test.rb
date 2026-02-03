# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/saas/user_generator"

class SaasUserGeneratorTest < Rails::Generators::TestCase
  tests Pu::Saas::UserGenerator
  destination Rails.root

  def setup
    # Backup rodauth_app.rb
    @rodauth_app_backup = File.read(destination_root.join("app/rodauth/rodauth_app.rb"))

    # Backup root Gemfile
    @root_gemfile_path = File.expand_path("../../Gemfile", __dir__)
    @gemfile_backup = File.read(@root_gemfile_path)
  end

  def teardown
    cleanup_generated_files("test_user")

    # Restore rodauth_app.rb
    File.write(destination_root.join("app/rodauth/rodauth_app.rb"), @rodauth_app_backup)

    # Restore root Gemfile
    File.write(@root_gemfile_path, @gemfile_backup)
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

  private

  def cleanup_generated_files(name)
    normalized = name.underscore
    files = [
      "app/models/#{normalized}.rb",
      "app/definitions/#{normalized}_definition.rb",
      "app/policies/#{normalized}_policy.rb",
      "app/rodauth/#{normalized}_rodauth_plugin.rb",
      "app/views/rodauth/#{normalized}",
      "app/views/rodauth/#{normalized}_mailer",
      "app/mailers/rodauth/#{normalized}_mailer.rb",
      "app/controllers/#{normalized.pluralize}_controller.rb",
      "app/controllers/rodauth/#{normalized}_controller.rb"
    ]

    files.each { |f| FileUtils.rm_rf(destination_root.join(f)) }

    Dir.glob(destination_root.join("db/migrate/*_#{normalized}*.rb")).each do |f|
      FileUtils.rm(f)
    end
  end
end

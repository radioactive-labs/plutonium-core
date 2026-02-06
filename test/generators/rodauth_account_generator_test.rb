# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/rodauth/account_generator"

class RodauthAccountGeneratorTest < Rails::Generators::TestCase
  tests Pu::Rodauth::AccountGenerator
  destination Rails.root

  def setup
    @created_files = []
    @modified_files = {}

    # Backup rodauth_app.rb
    @rodauth_app_backup = File.read(destination_root.join("app/rodauth/rodauth_app.rb"))

    # Backup root Gemfile (generator adds gems to project root)
    @root_gemfile_path = File.expand_path("../../Gemfile", __dir__)
    @gemfile_backup = File.read(@root_gemfile_path)
  end

  def teardown
    # Clean up created files
    cleanup_generated_files("test_account")

    # Restore rodauth_app.rb
    File.write(destination_root.join("app/rodauth/rodauth_app.rb"), @rodauth_app_backup)

    # Restore root Gemfile
    File.write(@root_gemfile_path, @gemfile_backup)
  end

  test "generates named account configuration" do
    run_generator ["TestAccount"]

    # Should register with a name, not as primary
    assert_file "app/rodauth/rodauth_app.rb" do |content|
      assert_match(/configure ::TestAccountRodauthPlugin, :test_account/, content)
      assert_match(/r\.rodauth\(:test_account\)/, content)
    end
  end

  test "generates model with named configuration" do
    run_generator ["TestAccount"]

    assert_file "app/models/test_account.rb" do |content|
      assert_match(/include Rodauth::Rails\.model\(:test_account\)/, content)
    end
  end

  test "generates plugin with prefix for named account" do
    run_generator ["TestAccount"]

    assert_file "app/rodauth/test_account_rodauth_plugin.rb" do |content|
      # Named accounts should have a prefix (not commented out)
      assert_match(/^\s+prefix "\/test_accounts"/, content)
    end
  end

  test "primary option is ignored" do
    # Even with --primary flag, account should be named
    run_generator ["TestAccount", "--primary"]

    assert_file "app/rodauth/rodauth_app.rb" do |content|
      # Should still register with a name
      assert_match(/configure ::TestAccountRodauthPlugin, :test_account/, content)
    end
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
      "app/mailers/#{normalized}_mailer.rb",
      "app/mailers/rodauth/#{normalized}_mailer.rb",
      "app/controllers/#{normalized.pluralize}_controller.rb",
      "app/controllers/rodauth/#{normalized}_controller.rb"
    ]

    files.each { |f| FileUtils.rm_rf(destination_root.join(f)) }

    # Clean up migrations
    Dir.glob(destination_root.join("db/migrate/*_#{normalized}*.rb")).each do |f|
      FileUtils.rm(f)
    end
  end
end

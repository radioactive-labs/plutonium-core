# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/rodauth/account_generator"

class RodauthAccountGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Rodauth::AccountGenerator
  destination Rails.root

  def setup
    git_ensure_clean_dummy_app
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
end

# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/saas/api_client_generator"

class SaasApiClientGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Saas::ApiClientGenerator
  destination Rails.root

  def setup
    git_ensure_clean_dummy_app
  end

  test "generates basic api client without entity" do
    run_generator ["TestApiClient", "--dest=main_app"]

    assert_file "app/models/test_api_client.rb" do |content|
      assert_match(/include Rodauth::Rails\.model\(:test_api_client\)/, content)
    end

    assert_file "app/rodauth/test_api_client_rodauth_plugin.rb" do |content|
      assert_match(/login_column :login/, content)
      assert_match(/require_email_address_logins\? false/, content)
      assert_match(/before_create_account_route do/, content)
      assert_match(/request\.halt unless internal_request\?/, content)
    end
  end

  test "generates create interaction" do
    run_generator ["TestApiClient", "--dest=main_app"]

    assert_file "app/interactions/test_api_client/create_interaction.rb" do |content|
      assert_match(/class TestApiClient::CreateInteraction/, content)
      assert_match(/include Plutonium::ApiClient::Concerns::CreateApiClient/, content)
      assert_match(/def rodauth_name/, content)
      assert_match(/:test_api_client/, content)
    end
  end

  test "generates disable interaction" do
    run_generator ["TestApiClient", "--dest=main_app"]

    assert_file "app/interactions/test_api_client/disable_interaction.rb" do |content|
      assert_match(/class TestApiClient::DisableInteraction/, content)
      assert_match(/include Plutonium::ApiClient::Concerns::DisableApiClient/, content)
    end
  end

  test "generates rake task with create only" do
    run_generator ["TestApiClient", "--dest=main_app"]

    assert_file "lib/tasks/test_api_client.rake" do |content|
      assert_match(/namespace :test_api_clients/, content)
      assert_match(/task create: :environment/, content)
      assert_match(/RodauthApp\.rodauth\(:test_api_client\)\.create_account/, content)
      assert_match(/SecureRandom\.base64\(32\)/, content)
      # Should NOT have disable or list tasks
      refute_match(/task disable:/, content)
      refute_match(/task list:/, content)
    end
  end

  test "injects actions into definition" do
    run_generator ["TestApiClient", "--dest=main_app"]

    assert_file "app/definitions/test_api_client_definition.rb" do |content|
      assert_match(/action :register, interaction: TestApiClient::CreateInteraction/, content)
      assert_match(/action :disable, interaction: TestApiClient::DisableInteraction/, content)
    end
  end

  test "configures policy to prevent direct create" do
    run_generator ["TestApiClient", "--dest=main_app"]

    assert_file "app/policies/test_api_client_policy.rb" do |content|
      assert_match(/def create\?\s*\n\s*false\s*\n\s*end/, content)
      assert_match(/def register\?\s*\n\s*true\s*\n\s*end/, content)
      assert_match(/def disable\?/, content)
    end
  end

  test "generates with entity scoping" do
    # First create an entity
    create_test_entity

    run_generator ["TestApiClient", "--entity=TestOrg", "--dest=main_app"]

    # Should create membership model
    assert_file "app/models/test_org_test_api_client.rb" do |content|
      assert_match(/belongs_to :test_org/, content)
      assert_match(/belongs_to :test_api_client/, content)
      assert_match(/enum :role/, content)
    end

    # Create interaction should have entity scoping
    assert_file "app/interactions/test_api_client/create_interaction.rb" do |content|
      assert_match(/attribute :test_org_id/, content)
      assert_match(/def entity_class/, content)
      assert_match(/TestOrg/, content)
      assert_match(/def membership_class/, content)
      assert_match(/TestOrgTestApiClient/, content)
    end

    # Rake task should include entity
    assert_file "lib/tasks/test_api_client.rake" do |content|
      assert_match(/test_org_name = ENV\["TEST_ORG"\]/, content)
      assert_match(/TestOrgTestApiClient\.create!/, content)
    end
  end

  test "generates with custom roles" do
    create_test_entity

    run_generator ["TestApiClient", "--entity=TestOrg", "--roles=reader,writer,admin", "--dest=main_app"]

    assert_file "app/models/test_org_test_api_client.rb" do |content|
      assert_match(/enum :role, \{reader: 0, writer: 1, admin: 2\}/, content)
    end
  end

  test "uses login column instead of email" do
    run_generator ["TestApiClient", "--dest=main_app"]

    migration_files = Dir[destination_root.join("db/migrate/*test_api_client*.rb")]
    assert migration_files.any?, "Migration file should exist"

    migration_content = File.read(migration_files.first)
    assert_match(/t\.\w+ :login/, migration_content)
    refute_match(/t\.\w+ :email/, migration_content)
  end

  private

  def create_test_entity
    # Create a minimal entity model for testing
    FileUtils.mkdir_p(destination_root.join("app/models"))
    File.write(destination_root.join("app/models/test_org.rb"), <<~RUBY)
      class TestOrg < ResourceRecord
        # add concerns above.

        # add belongs_to associations above.

        # add has_many associations above.

        # add enums above.

        # add scopes above.

        # add validations above.

        # add callbacks above.
      end
    RUBY
  end
end

# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators"
require "generators/pu/saas/setup_generator"

class SaasSetupGeneratorTest < ActiveSupport::TestCase
  include GeneratorTestHelper

  def setup
    @rails_root = Rails.root

    # Ensure clean state before each test
    git_ensure_clean_dummy_app
  end

  test "generates complete saas setup" do
    run_setup_generator ["--user=TestCustomer", "--entity=TestCompany", "--dest=main_app"]

    # User account should exist
    assert File.exist?(@rails_root.join("app/models/test_customer.rb")), "test_customer.rb should exist"
    customer_model = File.read(@rails_root.join("app/models/test_customer.rb"))
    assert_match(/include Rodauth::Rails\.model\(:test_customer\)/, customer_model)

    # Entity should exist
    assert File.exist?(@rails_root.join("app/models/test_company.rb")), "test_company.rb should exist"

    # Membership should exist
    assert File.exist?(@rails_root.join("app/models/test_company_test_customer.rb")), "test_company_test_customer.rb should exist"
    membership_model = File.read(@rails_root.join("app/models/test_company_test_customer.rb"))
    assert_match(/belongs_to :test_company/, membership_model)
    assert_match(/belongs_to :test_customer/, membership_model)
    assert_match(/enum :role/, membership_model)
  end

  test "generates with custom roles" do
    run_setup_generator ["--user=TestCustomer", "--entity=TestCompany", "--roles=member,admin,owner", "--dest=main_app"]

    membership_model = File.read(@rails_root.join("app/models/test_company_test_customer.rb"))
    assert_match(/enum :role, member: 0, admin: 1, owner: 2/, membership_model)
  end

  test "skip_entity option skips entity generation" do
    run_setup_generator ["--user=TestCustomer", "--entity=TestCompany", "--skip-entity", "--skip-membership", "--dest=main_app"]

    assert File.exist?(@rails_root.join("app/models/test_customer.rb")), "test_customer.rb should exist"
    refute File.exist?(@rails_root.join("app/models/test_company.rb")), "test_company.rb should not exist"
    refute File.exist?(@rails_root.join("app/models/test_company_test_customer.rb")), "test_company_test_customer.rb should not exist"
  end

  test "adds dependent destroy to associations" do
    run_setup_generator ["--user=TestCustomer", "--entity=TestCompany", "--dest=main_app"]

    customer_model = File.read(@rails_root.join("app/models/test_customer.rb"))
    assert_match(/has_many :test_company_test_customers, dependent: :destroy/, customer_model)

    company_model = File.read(@rails_root.join("app/models/test_company.rb"))
    assert_match(/has_many :test_company_test_customers, dependent: :destroy/, company_model)
  end

  test "generates api_client when flag provided" do
    run_setup_generator ["--user=TestCustomer", "--entity=TestCompany", "--api_client=TestApiClient", "--dest=main_app"]

    # API client model should exist
    assert File.exist?(@rails_root.join("app/models/test_api_client.rb")), "test_api_client.rb should exist"

    # API client membership should exist (scoped to entity)
    assert File.exist?(@rails_root.join("app/models/test_company_test_api_client.rb")), "test_company_test_api_client.rb should exist"
    api_membership = File.read(@rails_root.join("app/models/test_company_test_api_client.rb"))
    assert_match(/belongs_to :test_company/, api_membership)
    assert_match(/belongs_to :test_api_client/, api_membership)

    # Create interaction should exist
    assert File.exist?(@rails_root.join("app/interactions/test_api_client/create_interaction.rb")), "create_interaction.rb should exist"

    # Rake task should exist
    assert File.exist?(@rails_root.join("lib/tasks/test_api_client.rake")), "rake task should exist"
  end

  test "api_client not scoped to entity when skip_entity" do
    run_setup_generator ["--user=TestCustomer", "--entity=TestCompany", "--skip-entity", "--skip-membership", "--api_client=TestApiClient", "--dest=main_app"]

    # API client should exist
    assert File.exist?(@rails_root.join("app/models/test_api_client.rb")), "test_api_client.rb should exist"

    # No entity membership should exist
    refute File.exist?(@rails_root.join("app/models/test_company_test_api_client.rb")), "test_company_test_api_client.rb should not exist"

    # Create interaction should not have entity references
    create_interaction = File.read(@rails_root.join("app/interactions/test_api_client/create_interaction.rb"))
    refute_match(/test_company_id/, create_interaction)
  end

  private

  def run_setup_generator(args)
    Dir.chdir(@rails_root) do
      Pu::Saas::SetupGenerator.start(args, destination_root: @rails_root)
    end
  end
end

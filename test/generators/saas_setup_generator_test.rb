# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

# Clean up any leftover migrations BEFORE loading test_helper
require "fileutils"
rails_root = File.expand_path("../dummy", __dir__)

Dir.glob(File.join(rails_root, "db/migrate/*_test_customer*.rb")).each { |f| FileUtils.rm(f) }
Dir.glob(File.join(rails_root, "db/migrate/*_test_company*.rb")).each { |f| FileUtils.rm(f) }
FileUtils.rm_f(File.join(rails_root, "storage/test.sqlite3"))

require "test_helper"
require "rails/generators"
require "generators/pu/saas/setup_generator"

class SaasSetupGeneratorTest < ActiveSupport::TestCase
  def setup
    @rails_root = Rails.root

    cleanup_all_files

    # Backup rodauth_app.rb
    @rodauth_app_backup = File.read(@rails_root.join("app/rodauth/rodauth_app.rb"))

    # Backup root Gemfile
    @root_gemfile_path = File.expand_path("../../Gemfile", __dir__)
    @gemfile_backup = File.read(@root_gemfile_path)
  end

  def teardown
    cleanup_all_files

    # Restore rodauth_app.rb
    File.write(@rails_root.join("app/rodauth/rodauth_app.rb"), @rodauth_app_backup)

    # Restore root Gemfile
    File.write(@root_gemfile_path, @gemfile_backup)
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

  private

  def run_setup_generator(args)
    Dir.chdir(@rails_root) do
      Pu::Saas::SetupGenerator.start(args, destination_root: @rails_root)
    end
  end

  def cleanup_all_files
    cleanup_user_files("test_customer")
    cleanup_entity_files("test_company")
    cleanup_membership_files("test_company_test_customer")
  end

  def cleanup_user_files(name)
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

    files.each { |f| FileUtils.rm_rf(@rails_root.join(f)) }

    Dir.glob(@rails_root.join("db/migrate/*rodauth*#{normalized}*.rb")).each do |f|
      FileUtils.rm(f)
    end
  end

  def cleanup_entity_files(name)
    normalized = name.underscore
    files = [
      "app/models/#{normalized}.rb",
      "app/definitions/#{normalized}_definition.rb",
      "app/policies/#{normalized}_policy.rb",
      "app/controllers/#{normalized.pluralize}_controller.rb"
    ]

    files.each { |f| FileUtils.rm_rf(@rails_root.join(f)) }

    Dir.glob(@rails_root.join("db/migrate/*_create_#{normalized.pluralize}.rb")).each do |f|
      FileUtils.rm(f)
    end
  end

  def cleanup_membership_files(name)
    normalized = name.underscore
    files = [
      "app/models/#{normalized}.rb",
      "app/definitions/#{normalized}_definition.rb",
      "app/policies/#{normalized}_policy.rb",
      "app/controllers/#{normalized.pluralize}_controller.rb"
    ]

    files.each { |f| FileUtils.rm_rf(@rails_root.join(f)) }

    Dir.glob(@rails_root.join("db/migrate/*_create_#{normalized.pluralize}.rb")).each do |f|
      FileUtils.rm(f)
    end
  end
end

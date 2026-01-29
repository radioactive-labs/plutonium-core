# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

# Clean up any leftover customer/client migrations and database BEFORE loading test_helper
# (which runs migrations at load time)
require "fileutils"
rails_root = File.expand_path("../dummy", __dir__)

# Delete migrations
Dir.glob(File.join(rails_root, "db/migrate/*_customer*.rb")).each { |f| FileUtils.rm(f) }
Dir.glob(File.join(rails_root, "db/migrate/*_client*.rb")).each { |f| FileUtils.rm(f) }

# Delete test database to ensure fresh state
FileUtils.rm_f(File.join(rails_root, "storage/test.sqlite3"))

require "test_helper"
require "rails/generators"
require "generators/pu/rodauth/customer_generator"

class RodauthCustomerGeneratorTest < ActiveSupport::TestCase
  def setup
    @rails_root = Rails.root

    # Clean up any leftover files from previous test runs
    cleanup_generated_files("customer")
    cleanup_entity_files("client")

    # Backup rodauth_app.rb
    @rodauth_app_backup = File.read(@rails_root.join("app/rodauth/rodauth_app.rb"))

    # Backup root Gemfile (generator may add gems to project root)
    @root_gemfile_path = File.expand_path("../../Gemfile", __dir__)
    @gemfile_backup = File.read(@root_gemfile_path)
  end

  def teardown
    cleanup_generated_files("customer")
    cleanup_entity_files("client")

    # Restore rodauth_app.rb
    File.write(@rails_root.join("app/rodauth/rodauth_app.rb"), @rodauth_app_backup)

    # Restore root Gemfile
    File.write(@root_gemfile_path, @gemfile_backup)
  end

  test "generates customer account with rodauth plugin" do
    run_customer_generator ["Customer", "--entity=Client"]

    customer_model = File.read(@rails_root.join("app/models/customer.rb"))
    assert_match(/class Customer < ResourceRecord/, customer_model)
    assert_match(/include Rodauth::Rails\.model\(:customer\)/, customer_model)

    plugin = File.read(@rails_root.join("app/rodauth/customer_rodauth_plugin.rb"))
    assert_match(/accounts_table :customers/, plugin)
  end

  test "generates entity and membership models" do
    run_customer_generator ["Customer", "--entity=Client"]

    assert File.exist?(@rails_root.join("app/models/client.rb")), "client.rb should exist"
    client_model = File.read(@rails_root.join("app/models/client.rb"))
    assert_match(/class Client/, client_model)

    assert File.exist?(@rails_root.join("app/models/client_customer.rb")), "client_customer.rb should exist"
    membership_model = File.read(@rails_root.join("app/models/client_customer.rb"))
    assert_match(/belongs_to :client/, membership_model)
    assert_match(/belongs_to :customer/, membership_model)
  end

  test "accepts extra_attributes option" do
    assert_nothing_raised do
      run_customer_generator ["Customer", "--entity=Client", "--extra-attributes=name:string"]
    end

    assert File.exist?(@rails_root.join("app/models/customer.rb"))
  end

  private

  def run_customer_generator(args)
    Dir.chdir(@rails_root) do
      Pu::Rodauth::CustomerGenerator.start(args, destination_root: @rails_root)
    end
  end

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

    files.each { |f| FileUtils.rm_rf(@rails_root.join(f)) }

    # Clean up migrations - rodauth migrations have long names with features
    Dir.glob(@rails_root.join("db/migrate/*_#{normalized}*.rb")).each do |f|
      FileUtils.rm(f)
    end
  end

  def cleanup_entity_files(entity_name)
    normalized = entity_name.underscore
    files = [
      "app/models/#{normalized}.rb",
      "app/definitions/#{normalized}_definition.rb",
      "app/policies/#{normalized}_policy.rb",
      "app/models/#{normalized}_customer.rb",
      "app/definitions/#{normalized}_customer_definition.rb",
      "app/policies/#{normalized}_customer_policy.rb",
      "app/controllers/#{normalized.pluralize}_controller.rb",
      "app/controllers/#{normalized}_customers_controller.rb"
    ]

    files.each { |f| FileUtils.rm_rf(@rails_root.join(f)) }

    # Clean up migrations
    Dir.glob(@rails_root.join("db/migrate/*_#{normalized}*.rb")).each do |f|
      FileUtils.rm(f)
    end
    Dir.glob(@rails_root.join("db/migrate/*_#{normalized}_customers.rb")).each do |f|
      FileUtils.rm(f)
    end
  end
end

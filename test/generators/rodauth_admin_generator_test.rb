# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/rodauth/admin_generator"

class RodauthAdminGeneratorTest < Rails::Generators::TestCase
  tests Pu::Rodauth::AdminGenerator
  destination Rails.root

  def setup
    @created_files = []
    @modified_files = {}

    # Backup rodauth_app.rb
    @rodauth_app_backup = File.read(destination_root.join("app/rodauth/rodauth_app.rb"))

    # Backup root Gemfile (generator adds rotp and rqrcode gems to project root)
    @root_gemfile_path = File.expand_path("../../Gemfile", __dir__)
    @gemfile_backup = File.read(@root_gemfile_path)
  end

  def teardown
    # Clean up created files
    cleanup_generated_files("test_admin")

    # Restore rodauth_app.rb
    File.write(destination_root.join("app/rodauth/rodauth_app.rb"), @rodauth_app_backup)

    # Restore root Gemfile
    File.write(@root_gemfile_path, @gemfile_backup)
  end

  test "generates admin account with role enum" do
    run_generator ["TestAdmin"]

    assert_file "app/models/test_admin.rb" do |content|
      assert_match(/enum :role, super_admin: 0, admin: 1/, content)
    end
  end

  test "generates admin with custom roles" do
    run_generator ["TestAdmin", "--roles=owner,manager,viewer"]

    assert_file "app/models/test_admin.rb" do |content|
      assert_match(/enum :role, owner: 0, manager: 1, viewer: 2/, content)
    end
  end

  test "generates invite interaction with correct default role" do
    run_generator ["TestAdmin"]

    assert_file "app/interactions/test_admin/invite_interaction.rb" do |content|
      assert_match(/class TestAdmin::InviteInteraction/, content)
      assert_match(/attribute :email/, content)
      assert_match(/attribute :role, default: :admin/, content)
      assert_match(/validates :role, presence: true, inclusion: \{in: TestAdmin\.roles\.keys\}/, content)
      assert_match(/input :role, as: :select, choices: TestAdmin\.roles\.keys/, content)
    end
  end

  test "generates invite interaction with single role defaults to that role" do
    run_generator ["TestAdmin", "--roles=owner"]

    assert_file "app/interactions/test_admin/invite_interaction.rb" do |content|
      assert_match(/attribute :role, default: :owner/, content)
    end
  end

  test "injects invite action into definition" do
    run_generator ["TestAdmin"]

    assert_file "app/definitions/test_admin_definition.rb" do |content|
      assert_match(/action :invite, interaction: TestAdmin::InviteInteraction, collection: true, category: :primary/, content)
    end
  end

  test "injects invite policy method" do
    run_generator ["TestAdmin"]

    assert_file "app/policies/test_admin_policy.rb" do |content|
      assert_match(/def invite\?\s*\n\s*true\s*\n\s*end/, content)
    end
  end

  test "accepts extra_attributes option without error" do
    # extra_attributes are passed through to account generator
    # Currently they only affect scaffold (definition/policy), not migration
    assert_nothing_raised do
      run_generator ["TestAdmin", "--extra-attributes=department:string", "phone:string"]
    end

    # Basic files should still be generated
    assert_file "app/models/test_admin.rb"
    assert_file "app/definitions/test_admin_definition.rb"
    assert_file "app/policies/test_admin_policy.rb"
  end

  test "configures rodauth plugin for admin" do
    run_generator ["TestAdmin"]

    assert_file "app/rodauth/test_admin_rodauth_plugin.rb" do |content|
      # Should prevent web signup
      assert_match(/before_create_account_route do/, content)
      assert_match(/request\.halt unless internal_request\?/, content)
      # Should use multi-phase login
      assert_match(/use_multi_phase_login\? true/, content)
    end
  end

  test "generates rake task for admin" do
    run_generator ["TestAdmin"]

    assert_file "lib/tasks/rodauth_test_admin.rake" do |content|
      assert_match(/namespace :rodauth/, content)
      assert_match(/task test_admin: :environment/, content)
      assert_match(/RodauthApp\.rodauth\(:test_admin\)\.create_account/, content)
    end
  end

  test "adds role column to migration with proper options" do
    run_generator ["TestAdmin"]

    migration_files = Dir[destination_root.join("db/migrate/*_test_admin*.rb")]
    assert migration_files.any?, "Migration file should exist"

    migration_content = File.read(migration_files.first)
    assert_match(/t\.integer :role, null: false, default: 0/, migration_content)
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
      "app/interactions/#{normalized}",
      "app/mailers/#{normalized}_mailer.rb",
      "app/mailers/rodauth/#{normalized}_mailer.rb",
      "app/controllers/#{normalized.pluralize}_controller.rb",
      "app/controllers/rodauth/#{normalized}_controller.rb",
      "lib/tasks/rodauth_#{normalized}.rake"
    ]

    files.each { |f| FileUtils.rm_rf(destination_root.join(f)) }

    # Clean up migrations - rodauth migrations have long names with features
    Dir.glob(destination_root.join("db/migrate/*_#{normalized}*.rb")).each do |f|
      FileUtils.rm(f)
    end
  end
end

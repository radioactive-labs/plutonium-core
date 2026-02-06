# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/invites/install_generator"

class InvitesInstallGeneratorTest < Rails::Generators::TestCase
  tests Pu::Invites::InstallGenerator
  # Use Rails.root as destination since generator validates files there
  destination Rails.root
  # Don't use prepare_destination - it clears Rails.root!

  # Track files created by generator for cleanup
  def setup
    @created_files = []
    @modified_files = {}

    # Backup files that will be modified
    backup_file("app/models/organization.rb")
    backup_file("app/definitions/organization_definition.rb")
    backup_file("app/policies/organization_policy.rb")
    backup_file("app/definitions/user_definition.rb")
    backup_file("app/policies/user_policy.rb")
    backup_file("app/policies/resource_policy.rb")
    backup_file("app/rodauth/user_rodauth_plugin.rb")
    backup_file("config/routes.rb")
  end

  def teardown
    # Clean up created files
    @created_files.each { |f| FileUtils.rm_rf(destination_root.join(f)) }

    # Restore modified files
    @modified_files.each do |path, content|
      if content
        File.write(destination_root.join(path), content)
      end
    end

    # Clean up packages/invites if created
    FileUtils.rm_rf(destination_root.join("packages/invites"))

    # Clean up migration
    Dir.glob(destination_root.join("db/migrate/*_create_user_invites.rb")).each do |f|
      FileUtils.rm(f)
    end

    # Clean up generated interactions
    FileUtils.rm_rf(destination_root.join("app/interactions/organization"))
    FileUtils.rm_rf(destination_root.join("app/interactions/user"))
  end

  # Default args for all tests
  def default_args
    ["--entity-model=Organization"]
  end

  test "generates migration" do
    run_generator default_args

    assert_migration "db/migrate/create_user_invites.rb" do |content|
      assert_match(/create_table :user_invites/, content)
      assert_match(/t\.belongs_to :organization/, content)
      assert_match(/t\.text :token, null: false/, content)
      assert_match(/t\.integer :role/, content)
      assert_match(/t\.integer :state/, content)
      assert_match(/t\.belongs_to :invited_by.*polymorphic: true/, content)
      assert_match(/t\.belongs_to :user/, content)
      assert_match(/t\.belongs_to :invitable.*polymorphic: true/, content)
      assert_match(/t\.index :token, unique: true/, content)
    end
  end

  test "generates user invite model" do
    run_generator default_args

    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/class UserInvite < Invites::ResourceRecord/, content)
      assert_match(/include Plutonium::Invites::Concerns::InviteToken/, content)
      assert_match(/encrypts :token, deterministic: true/, content)
      assert_match(/belongs_to :organization/, content)
      assert_match(/belongs_to :invited_by, polymorphic: true/, content)
      assert_match(/belongs_to :user, optional: true/, content)
      assert_match(/belongs_to :invitable, polymorphic: true, optional: true/, content)
      assert_match(/def invitation_mailer/, content)
      assert_match(/def create_membership_for/, content)
      assert_match(/alias_method :entity, :organization/, content)
    end
  end

  test "generates model with custom roles" do
    run_generator default_args + ["--roles=member,admin,owner"]

    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/enum :role, member: 0, admin: 1, owner: 2/, content)
    end
  end

  test "generates model with enforce_domain when option passed" do
    run_generator default_args + ["--enforce-domain"]

    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/def enforce_domain/, content)
      assert_match(/raise NotImplementedError/, content)
    end
  end

  test "generates model without enforce_domain by default" do
    run_generator default_args

    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/def enforce_domain/, content)
      assert_match(/nil/, content)
      assert_no_match(/raise NotImplementedError.*enforce_domain/, content)
    end
  end

  test "generates mailer and email templates" do
    run_generator default_args

    assert_file "packages/invites/app/mailers/invites/user_invite_mailer.rb" do |content|
      assert_match(/class UserInviteMailer < ApplicationMailer/, content)
      assert_match(/def invitation\(user_invite\)/, content)
      assert_match(/invitation_template_name/, content)
    end

    assert_file "packages/invites/app/views/invites/user_invite_mailer/invitation.html.erb"
    assert_file "packages/invites/app/views/invites/user_invite_mailer/invitation.text.erb"
  end

  test "generates user invitations controller" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/user_invitations_controller.rb" do |content|
      assert_match(/class UserInvitationsController < ApplicationController/, content)
      assert_match(/include Plutonium::Invites::Controller/, content)
      assert_match(/def invite_class/, content)
      assert_match(/Invites::UserInvite/, content)
    end
  end

  test "generates user invitations controller with named rodauth config" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/user_invitations_controller.rb" do |content|
      # Should use named config syntax, not parameterized rodauth call
      assert_match(/def rodauth/, content)
      assert_match(/request\.env\["rodauth\.user"\]/, content)
      # Should not have parameterized rodauth calls
      assert_no_match(/rodauth\(:user\)/, content)
    end
  end

  test "generates welcome controller" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_match(/class WelcomeController < ApplicationController/, content)
      assert_match(/include Plutonium::Invites::PendingInviteCheck/, content)
      assert_match(/def index/, content)
      assert_match(/pending_invite/, content)
    end
  end

  test "generates welcome controller with named rodauth config" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      # Should use named config syntax
      assert_match(/def rodauth/, content)
      assert_match(/request\.env\["rodauth\.user"\]/, content)
      # Should not have parameterized rodauth calls
      assert_no_match(/rodauth\(:user\)/, content)
    end
  end

  test "generates views" do
    run_generator default_args

    assert_file "packages/invites/app/views/invites/user_invitations/landing.html.erb"
    assert_file "packages/invites/app/views/invites/user_invitations/show.html.erb"
    assert_file "packages/invites/app/views/invites/user_invitations/signup.html.erb"
    assert_file "packages/invites/app/views/invites/user_invitations/error.html.erb"
    assert_file "packages/invites/app/views/invites/welcome/pending_invitation.html.erb"
    assert_file "packages/invites/app/views/layouts/invites/invitation.html.erb"
  end

  test "generates interactions" do
    run_generator default_args

    assert_file "packages/invites/app/interactions/invites/resend_invite_interaction.rb" do |content|
      assert_match(/include Plutonium::Invites::Concerns::ResendInvite/, content)
    end

    assert_file "packages/invites/app/interactions/invites/cancel_invite_interaction.rb" do |content|
      assert_match(/include Plutonium::Invites::Concerns::CancelInvite/, content)
    end
  end

  test "generates definition" do
    run_generator default_args

    assert_file "packages/invites/app/definitions/invites/user_invite_definition.rb" do |content|
      assert_match(/class UserInviteDefinition/, content)
    end
  end

  test "generates policy" do
    run_generator default_args

    assert_file "packages/invites/app/policies/invites/user_invite_policy.rb" do |content|
      assert_match(/class UserInvitePolicy/, content)
    end
  end

  test "generates entity invite interaction" do
    run_generator default_args

    assert_file "app/interactions/organization/invite_user_interaction.rb" do |content|
      assert_match(/class Organization::InviteUserInteraction/, content)
      assert_match(/include Plutonium::Invites::Concerns::InviteUser/, content)
    end
  end

  test "generates user invite interaction" do
    run_generator default_args

    assert_file "app/interactions/user/invite_user_interaction.rb" do |content|
      assert_match(/class User::InviteUserInteraction/, content)
      assert_match(/include Plutonium::Invites::Concerns::InviteUser/, content)
      assert_match(/def entity/, content)
      assert_match(/current_entity/, content)
    end
  end

  test "injects action into user definition" do
    run_generator default_args

    assert_file "app/definitions/user_definition.rb" do |content|
      assert_match(/action :invite_user/, content)
      assert_match(/User::InviteUserInteraction/, content)
    end
  end

  test "injects policy method into user policy" do
    run_generator default_args

    assert_file "app/policies/user_policy.rb" do |content|
      assert_match(/def invite_user\?/, content)
    end
  end

  test "injects association into entity model" do
    run_generator default_args

    assert_file "app/models/organization.rb" do |content|
      assert_match(/has_many :user_invites, class_name: "Invites::UserInvite"/, content)
    end
  end

  test "injects action into entity definition" do
    run_generator default_args

    assert_file "app/definitions/organization_definition.rb" do |content|
      assert_match(/action :invite_user/, content)
    end
  end

  test "injects policy method into entity policy" do
    run_generator default_args

    assert_file "app/policies/organization_policy.rb" do |content|
      assert_match(/def invite_user\?/, content)
    end
  end

  test "injects routes" do
    run_generator default_args

    assert_file "config/routes.rb" do |content|
      assert_match(/get "welcome"/, content)
      assert_match(/get "invitations\/:token"/, content)
      assert_match(/post "invitations\/:token\/accept"/, content)
      assert_match(/get "invitations\/:token\/signup"/, content)
      assert_match(/post "invitations\/:token\/signup"/, content)
    end
  end

  test "generates with custom user model" do
    # Create Account definition and policy for validation
    FileUtils.mkdir_p(destination_root.join("app/definitions"))
    FileUtils.mkdir_p(destination_root.join("app/policies"))
    File.write(destination_root.join("app/definitions/account_definition.rb"), <<~RUBY)
      class AccountDefinition < ::ResourceDefinition
      end
    RUBY
    File.write(destination_root.join("app/policies/account_policy.rb"), <<~RUBY)
      class AccountPolicy < ::ResourcePolicy
        # Core attributes
      end
    RUBY

    run_generator ["--entity-model=Organization", "--user-model=Account"]

    assert_migration "db/migrate/create_user_invites.rb" do |content|
      assert_match(/t\.belongs_to :account/, content)
    end

    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/belongs_to :account, optional: true/, content)
    end
  ensure
    FileUtils.rm_f(destination_root.join("app/definitions/account_definition.rb"))
    FileUtils.rm_f(destination_root.join("app/policies/account_policy.rb"))
    FileUtils.rm_rf(destination_root.join("app/interactions/account"))
  end

  test "generates with custom membership model" do
    run_generator ["--entity-model=Organization", "--membership-model=TeamMembership"]

    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/TeamMembership\.create!/, content)
    end
  end

  test "configures rodauth with session redirect in existing after_login" do
    run_generator default_args

    assert_file "app/rodauth/user_rodauth_plugin.rb" do |content|
      # Should add session redirect to existing after_login block
      assert_match(/after_welcome_redirect/, content)
      assert_match(/session\[:after_welcome_redirect\] = session\.delete\(:login_redirect\)/, content)
      # Should update login_redirect to /welcome
      assert_match(/login_redirect "\/welcome"/, content)
    end
  end

  test "skips rodauth configuration when already configured" do
    # First run
    run_generator default_args

    # Capture the file content after first run
    first_run_content = File.read(destination_root.join("app/rodauth/user_rodauth_plugin.rb"))

    # Run again - should skip
    run_generator default_args

    # Content should be the same (no duplicate injection)
    second_run_content = File.read(destination_root.join("app/rodauth/user_rodauth_plugin.rb"))
    assert_equal first_run_content, second_run_content
  end

  test "configures rodauth with multi-line after_login block" do
    rodauth_file = destination_root.join("app/rodauth/user_rodauth_plugin.rb")

    # Replace single-line with multi-line block
    content = File.read(rodauth_file)
    content.gsub!(/after_login \{ remember_login \}/, <<~RUBY.strip)
      after_login do
          remember_login
          log_login_event
        end
    RUBY
    File.write(rodauth_file, content)

    run_generator default_args

    assert_file "app/rodauth/user_rodauth_plugin.rb" do |content|
      # Should preserve existing code and add our line
      assert_match(/remember_login/, content)
      assert_match(/log_login_event/, content)
      assert_match(/session\[:after_welcome_redirect\] = session\.delete\(:login_redirect\)/, content)
      # Should update login_redirect to /welcome
      assert_match(/login_redirect "\/welcome"/, content)
    end
  end

  test "configures rodauth when no after_login block exists" do
    rodauth_file = destination_root.join("app/rodauth/user_rodauth_plugin.rb")

    # Remove all after_login references
    content = File.read(rodauth_file)
    content.gsub!(/^\s*after_login \{ remember_login \}\n/, "")
    content.gsub!(/^\s*# Or only remember.*\n/, "")
    content.gsub!(/^\s*# after_login \{ remember_login if.*\n/, "")
    File.write(rodauth_file, content)

    run_generator default_args

    assert_file "app/rodauth/user_rodauth_plugin.rb" do |content|
      # Should create new after_login block with only our code
      assert_match(/after_login do/, content)
      assert_match(/session\[:after_welcome_redirect\] = session\.delete\(:login_redirect\)/, content)
      # Should NOT have remember_login since it wasn't there before
      refute_match(/after_login do\s*\n\s*remember_login/, content)
      # Should update login_redirect to /welcome
      assert_match(/login_redirect "\/welcome"/, content)
    end
  end

  private

  def backup_file(path)
    full_path = destination_root.join(path)
    @modified_files[path] = File.exist?(full_path) ? File.read(full_path) : nil
  end
end

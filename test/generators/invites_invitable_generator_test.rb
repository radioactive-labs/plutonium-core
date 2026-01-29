# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/invites/invitable_generator"

class InvitesInvitableGeneratorTest < Rails::Generators::TestCase
  tests Pu::Invites::InvitableGenerator
  # Use Rails.root as destination since generator validates files there
  destination Rails.root
  # Don't use prepare_destination - it clears Rails.root!

  def setup
    @modified_files = {}

    # Backup files that will be modified
    backup_file("app/models/organization_user.rb")
    backup_file("app/definitions/organization_user_definition.rb")
    backup_file("app/policies/organization_user_policy.rb")
  end

  def teardown
    # Restore modified files
    @modified_files.each do |path, content|
      if content
        File.write(destination_root.join(path), content)
      end
    end

    # Clean up generated interaction
    FileUtils.rm_rf(destination_root.join("app/interactions/organization_user"))

    # Clean up generated email templates
    FileUtils.rm_f(destination_root.join("packages/invites/app/views/invites/user_invite_mailer/invitation_organization_user.html.erb"))
    FileUtils.rm_f(destination_root.join("packages/invites/app/views/invites/user_invite_mailer/invitation_organization_user.text.erb"))
  end

  test "generates invite user interaction" do
    run_generator ["OrganizationUser"]

    assert_file "app/interactions/organization_user/invite_user_interaction.rb" do |content|
      assert_match(/class OrganizationUser::InviteUserInteraction/, content)
      assert_match(/include Plutonium::Invites::Concerns::InviteUser/, content)
      assert_match(/def role/, content)
    end
  end

  test "generates interaction with custom role" do
    run_generator ["OrganizationUser", "--role=admin"]

    assert_file "app/interactions/organization_user/invite_user_interaction.rb" do |content|
      assert_match(/:admin/, content)
    end
  end

  test "injects invitable concern into model" do
    run_generator ["OrganizationUser"]

    assert_file "app/models/organization_user.rb" do |content|
      assert_match(/include Plutonium::Invites::Concerns::Invitable/, content)
    end
  end

  test "injects action into definition" do
    run_generator ["OrganizationUser"]

    assert_file "app/definitions/organization_user_definition.rb" do |content|
      assert_match(/action :invite_user/, content)
      assert_match(/OrganizationUser::InviteUserInteraction/, content)
    end
  end

  test "injects policy method with can_invite_user check" do
    run_generator ["OrganizationUser"]

    assert_file "app/policies/organization_user_policy.rb" do |content|
      assert_match(/def invite_user\?/, content)
      assert_match(/record\.can_invite_user\?/, content)
    end
  end

  test "generates email templates by default" do
    # Ensure the directory exists
    FileUtils.mkdir_p(destination_root.join("packages/invites/app/views/invites/user_invite_mailer"))

    run_generator ["OrganizationUser"]

    assert_file "packages/invites/app/views/invites/user_invite_mailer/invitation_organization_user.html.erb"
    assert_file "packages/invites/app/views/invites/user_invite_mailer/invitation_organization_user.text.erb"
  end

  test "skips email templates with no-email-templates option" do
    run_generator ["OrganizationUser", "--no-email-templates"]

    assert_no_file "packages/invites/app/views/invites/user_invite_mailer/invitation_organization_user.html.erb"
    assert_no_file "packages/invites/app/views/invites/user_invite_mailer/invitation_organization_user.text.erb"
  end

  private

  def backup_file(path)
    full_path = destination_root.join(path)
    @modified_files[path] = File.exist?(full_path) ? File.read(full_path) : nil
  end
end

# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators"
require "generators/pu/saas/membership_generator"

class SaasMembershipGeneratorTest < ActiveSupport::TestCase
  include GeneratorTestHelper

  def setup
    @rails_root = Rails.root

    # Ensure clean state before each test
    git_ensure_clean_dummy_app

    # Create minimal user and entity models for the membership generator to find
    create_minimal_model("saas_member")
    create_minimal_model("saas_org")
  end

  test "generates membership model with references" do
    run_membership_generator ["--user=SaasMember", "--entity=SaasOrg", "--dest=main_app"]

    assert File.exist?(@rails_root.join("app/models/saas_org_saas_member.rb")), "saas_org_saas_member.rb should exist"
    content = File.read(@rails_root.join("app/models/saas_org_saas_member.rb"))
    assert_match(/belongs_to :saas_org/, content)
    assert_match(/belongs_to :saas_member/, content)
  end

  test "generates membership with role enum" do
    run_membership_generator ["--user=SaasMember", "--entity=SaasOrg", "--dest=main_app"]

    content = File.read(@rails_root.join("app/models/saas_org_saas_member.rb"))
    assert_match(/enum :role, member: 0, owner: 1/, content)
  end

  test "generates membership with custom roles" do
    run_membership_generator ["--user=SaasMember", "--entity=SaasOrg", "--roles=viewer,editor,admin", "--dest=main_app"]

    content = File.read(@rails_root.join("app/models/saas_org_saas_member.rb"))
    assert_match(/enum :role, viewer: 0, editor: 1, admin: 2/, content)
  end

  test "adds uniqueness validation to model" do
    run_membership_generator ["--user=SaasMember", "--entity=SaasOrg", "--dest=main_app"]

    content = File.read(@rails_root.join("app/models/saas_org_saas_member.rb"))
    assert_match(/validates :saas_member, uniqueness: \{scope: :saas_org_id/, content)
  end

  test "adds associations to entity model" do
    run_membership_generator ["--user=SaasMember", "--entity=SaasOrg", "--dest=main_app"]

    content = File.read(@rails_root.join("app/models/saas_org.rb"))
    assert_match(/has_many :saas_org_saas_members, dependent: :destroy/, content)
    assert_match(/has_many :saas_members, through: :saas_org_saas_members/, content)
  end

  test "adds associations to user model" do
    run_membership_generator ["--user=SaasMember", "--entity=SaasOrg", "--dest=main_app"]

    content = File.read(@rails_root.join("app/models/saas_member.rb"))
    assert_match(/has_many :saas_org_saas_members, dependent: :destroy/, content)
    assert_match(/has_many :saas_orgs, through: :saas_org_saas_members/, content)
  end

  private

  def run_membership_generator(args)
    Dir.chdir(@rails_root) do
      # Ensure dest is always passed to avoid interactive prompts
      args << "--dest=main_app" unless args.any? { |a| a.include?("--dest") }
      Pu::Saas::MembershipGenerator.start(args, destination_root: @rails_root)
    end
  end

  def create_minimal_model(name)
    model_content = <<~RUBY
      class #{name.classify} < ::ResourceRecord
        # add concerns above.

        # add constants above.

        # add enums above.

        # add model configurations above.

        # add belongs_to associations above.

        # add has_one associations above.

        # add has_many associations above.

        # add attachments above.

        # add scopes above.

        # add validations above.

        # add callbacks above.

        # add delegations above.

        # add misc attribute macros above.

        # add methods above. add private methods below.
      end
    RUBY

    File.write(@rails_root.join("app/models/#{name}.rb"), model_content)
  end
end

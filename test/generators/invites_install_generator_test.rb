# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/invites/install_generator"

class InvitesInstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Invites::InstallGenerator
  # Use Rails.root as destination since generator validates files there
  destination Rails.root
  # Don't use prepare_destination - it clears Rails.root!

  def setup
    git_restore_dummy_app
  end

  # Default args for all tests
  def default_args
    ["--entity-model=Organization", "--dest=main_app"]
  end

  test "naming helpers derive correctly for default invite_model" do
    generator = Pu::Invites::InstallGenerator.new(
      [], {entity_model: "Organization", dest: "main_app"}
    )
    assert_equal "OrganizationUserInvite", generator.send(:invite_model)
    assert_equal "organization_user_invite", generator.send(:invite_underscore)
    assert_equal "organization_user_invites", generator.send(:invite_table)
    assert_equal "OrganizationUserInvitationsController", generator.send(:invitations_controller_class)
    assert_equal "organization_user_invitations", generator.send(:invitations_path)
    assert_equal "organization_user", generator.send(:invite_route_prefix)
  end

  test "naming helpers derive correctly for custom invite_model" do
    generator = Pu::Invites::InstallGenerator.new(
      [], {entity_model: "Organization", dest: "main_app", invite_model: "FunderInvite"}
    )
    assert_equal "FunderInvite", generator.send(:invite_model)
    assert_equal "funder_invite", generator.send(:invite_underscore)
    assert_equal "funder_invites", generator.send(:invite_table)
    assert_equal "FunderInvitationsController", generator.send(:invitations_controller_class)
    assert_equal "funder_invitations", generator.send(:invitations_path)
    assert_equal "funder", generator.send(:invite_route_prefix)
  end

  test "naming helpers flatten namespaced entity model in default derivation" do
    generator = Pu::Invites::InstallGenerator.new(
      [], {entity_model: "Blogging::Post", dest: "blogging"}
    )
    # "::" is stripped so the derived class name is single-segment.
    assert_equal "BloggingPostUserInvite", generator.send(:invite_model)
    assert_equal "blogging_post_user_invite", generator.send(:invite_underscore)
    assert_equal "blogging_post_user_invites", generator.send(:invite_table)
  end

  test "generates migration" do
    run_generator default_args

    assert_migration "db/migrate/create_organization_user_invites.rb" do |content|
      assert_match(/create_table :organization_user_invites/, content)
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

    assert_file "packages/invites/app/models/invites/organization_user_invite.rb" do |content|
      assert_match(/class OrganizationUserInvite < Invites::ResourceRecord/, content)
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

  test "generates model with enforce_domain when option passed" do
    run_generator default_args + ["--enforce-domain"]

    assert_file "packages/invites/app/models/invites/organization_user_invite.rb" do |content|
      assert_match(/def enforce_domain/, content)
      assert_match(/raise NotImplementedError/, content)
    end
  end

  test "generates model without enforce_domain by default" do
    run_generator default_args

    assert_file "packages/invites/app/models/invites/organization_user_invite.rb" do |content|
      assert_match(/def enforce_domain/, content)
      assert_match(/nil/, content)
      assert_no_match(/raise NotImplementedError.*enforce_domain/, content)
    end
  end

  test "generates model with roles from membership model" do
    # OrganizationUser in dummy app has: enum :role, member: 0, owner: 1
    run_generator default_args

    assert_file "packages/invites/app/models/invites/organization_user_invite.rb" do |content|
      # Should reference membership model's roles directly
      assert_match(/enum :role, OrganizationUser\.roles/, content)
    end
  end

  test "generates mailer and email templates" do
    run_generator default_args

    assert_file "packages/invites/app/mailers/invites/organization_user_invite_mailer.rb" do |content|
      assert_match(/class OrganizationUserInviteMailer < ApplicationMailer/, content)
      assert_match(/prepend_view_path Invites::Engine\.root\.join\("app\/views"\)/, content)
      assert_match(/def invitation\(invite\)/, content)
      assert_match(/invitation_template_name/, content)
    end

    assert_file "packages/invites/app/views/invites/organization_user_invite_mailer/invitation.html.erb"
    assert_file "packages/invites/app/views/invites/organization_user_invite_mailer/invitation.text.erb"
  end

  test "generates user invitations controller" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/organization_user_invitations_controller.rb" do |content|
      assert_match(/class OrganizationUserInvitationsController < ApplicationController/, content)
      assert_match(/include Plutonium::Invites::Controller/, content)
      assert_match(/def invite_class/, content)
      assert_match(/Invites::OrganizationUserInvite/, content)
    end
  end

  test "generates user invitations controller with rodauth module include" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/organization_user_invitations_controller.rb" do |content|
      # Should include the Rodauth module instead of a custom rodauth method
      assert_match(/include Plutonium::Auth::Rodauth\(:user\)/, content)
      assert_no_match(/def rodauth/, content)
      assert_no_match(/request\.env\["rodauth\.user"\]/, content)
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

  test "generates welcome controller with rodauth module include" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      # Should include the Rodauth module instead of a custom rodauth method
      assert_match(/include Plutonium::Auth::Rodauth\(:user\)/, content)
      assert_no_match(/def rodauth/, content)
      assert_no_match(/request\.env\["rodauth\.user"\]/, content)
    end
  end

  test "generates controllers without rodauth include when rodauth is blank" do
    run_generator ["--entity-model=Organization", "--dest=main_app", "--rodauth="]

    assert_file "packages/invites/app/controllers/invites/organization_user_invitations_controller.rb" do |content|
      assert_no_match(/include Plutonium::Auth::Rodauth/, content)
    end

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_no_match(/include Plutonium::Auth::Rodauth/, content)
    end
  end

  test "generates views" do
    run_generator default_args

    assert_file "packages/invites/app/views/invites/organization_user_invitations/landing.html.erb"
    assert_file "packages/invites/app/views/invites/organization_user_invitations/show.html.erb"
    assert_file "packages/invites/app/views/invites/organization_user_invitations/signup.html.erb"
    assert_file "packages/invites/app/views/invites/organization_user_invitations/error.html.erb"
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

    assert_file "packages/invites/app/definitions/invites/organization_user_invite_definition.rb" do |content|
      assert_match(/class OrganizationUserInviteDefinition/, content)
    end
  end

  test "generates policy" do
    run_generator default_args

    assert_file "packages/invites/app/policies/invites/organization_user_invite_policy.rb" do |content|
      assert_match(/class OrganizationUserInvitePolicy/, content)
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
      assert_match(/current_scoped_entity/, content)
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
      assert_match(/has_many :organization_user_invites, class_name: "Invites::OrganizationUserInvite"/, content)
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
      assert_match(/# Invitation welcome routes/, content)
      assert_match(/get "invitations\/welcome"/, content)
      assert_match(/delete "invitations\/welcome"/, content)
      assert_match(/# Invitation routes for OrganizationUserInvite/, content)
      assert_match(/get "organization_user_invitations\/:token"/, content)
      assert_match(/post "organization_user_invitations\/:token\/accept"/, content)
      assert_match(/get "organization_user_invitations\/:token\/signup"/, content)
      assert_match(/post "organization_user_invitations\/:token\/signup"/, content)
    end
  end

  test "scopes routes per invite_model" do
    run_generator default_args

    assert_file "config/routes.rb" do |content|
      assert_match(/get "organization_user_invitations\/:token", to: "organization_user_invitations#show", as: :organization_user_invitation/, content)
      assert_match(/post "organization_user_invitations\/:token\/accept", to: "organization_user_invitations#accept", as: :accept_organization_user_invitation/, content)
      assert_match(/get "invitations\/welcome".*as: :invites_welcome_check/, content)
    end
  end

  test "second invocation adds funder routes without duplicating welcome" do
    run_generator default_args
    run_generator default_args + ["--invite-model=FunderInvite"]

    assert_file "config/routes.rb" do |content|
      assert_match(/as: :organization_user_invitation\b/, content)
      assert_match(/as: :funder_invitation\b/, content)
      welcome_count = content.scan("as: :invites_welcome_check").size
      assert_equal 1, welcome_count, "expected exactly one welcome route, got #{welcome_count}"
    end
  end

  test "generates with custom user model" do
    # Create Account definition and policy for validation
    FileUtils.mkdir_p(destination_root.join("app/definitions"))
    FileUtils.mkdir_p(destination_root.join("app/policies"))
    FileUtils.mkdir_p(destination_root.join("app/models"))
    File.write(destination_root.join("app/definitions/account_definition.rb"), <<~RUBY)
      class AccountDefinition < ::ResourceDefinition
      end
    RUBY
    File.write(destination_root.join("app/policies/account_policy.rb"), <<~RUBY)
      class AccountPolicy < ::ResourcePolicy
        # Core attributes
      end
    RUBY
    # Membership model defaults to OrganizationAccount with custom user model
    File.write(destination_root.join("app/models/organization_account.rb"), <<~RUBY)
      class OrganizationAccount < ApplicationRecord
        enum :role, member: 0, owner: 1
      end
    RUBY

    run_generator ["--entity-model=Organization", "--user-model=Account", "--dest=main_app"]

    assert_migration "db/migrate/create_organization_account_invites.rb" do |content|
      assert_match(/t\.belongs_to :account/, content)
    end

    assert_file "packages/invites/app/models/invites/organization_account_invite.rb" do |content|
      assert_match(/belongs_to :account, optional: true/, content)
    end
  end

  test "generates with custom membership model" do
    # Create the TeamMembership model file so validation passes
    FileUtils.mkdir_p(destination_root.join("app/models"))
    File.write(destination_root.join("app/models/team_membership.rb"), <<~RUBY)
      class TeamMembership < ApplicationRecord
        enum :role, member: 0, admin: 1
      end
    RUBY

    run_generator ["--entity-model=Organization", "--membership-model=TeamMembership", "--dest=main_app"]

    assert_file "packages/invites/app/models/invites/organization_user_invite.rb" do |content|
      assert_match(/TeamMembership\.create!/, content)
    end
  end

  test "generates welcome controller with skip action" do
    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_match(/def skip/, content)
      assert_match(/cookies\.delete\(:pending_invitation\)/, content)
    end
  end

  test "welcome controller invite_classes accumulates across invocations" do
    run_generator default_args
    run_generator default_args + ["--invite-model=FunderInvite"]

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_match(/def invite_classes/, content)
      assert_match(/::Invites::OrganizationUserInvite/, content)
      assert_match(/::Invites::FunderInvite/, content)
      # Order matters for first-match semantics; both should appear in the same array literal.
      assert_match(/\[\s*::Invites::OrganizationUserInvite\s*,\s*::Invites::FunderInvite\s*\]/m, content)
    end
  end

  test "welcome controller invite_classes injection is idempotent" do
    run_generator default_args
    run_generator default_args  # second run, same invite_model
    run_generator default_args  # third run, same invite_model

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_equal 1, content.scan("::Invites::OrganizationUserInvite").size
    end
  end

  test "generates views with button_to for skip" do
    run_generator default_args

    assert_file "packages/invites/app/views/invites/welcome/pending_invitation.html.erb" do |content|
      assert_match(/button_to "Skip for Now"/, content)
      assert_match(/invites_welcome_skip_path/, content)
      assert_match(/method: :delete/, content)
    end

    assert_file "packages/invites/app/views/invites/organization_user_invitations/show.html.erb" do |content|
      assert_match(/button_to "Skip for Now"/, content)
      assert_match(/invites_welcome_skip_path/, content)
    end
  end

  test "adds standalone welcome route when no WelcomeController exists" do
    run_generator default_args

    assert_file "config/routes.rb" do |content|
      assert_match(/get "welcome", to: "invites\/welcome#index"/, content)
      # Exactly one — guards against the regex-with-alternation bug that
      # caused gsub-style double insertion before/after multiple anchors.
      count = content.scan(%(get "welcome", to: "invites/welcome#index")).size
      assert_equal 1, count, "expected exactly one standalone welcome route, got #{count}"
    end
  end

  test "skips standalone welcome route when WelcomeController exists" do
    # Create a WelcomeController before running the generator
    FileUtils.mkdir_p(destination_root.join("app/controllers"))
    File.write(destination_root.join("app/controllers/welcome_controller.rb"), <<~RUBY)
      class WelcomeController < AuthenticatedController
        def index
        end
      end
    RUBY

    run_generator default_args

    assert_file "config/routes.rb" do |content|
      assert_no_match(/get "welcome", to: "invites\/welcome#index"/, content)
    end
  end

  test "integrates invite check into existing WelcomeController" do
    # Create a WelcomeController before running the generator
    FileUtils.mkdir_p(destination_root.join("app/controllers"))
    File.write(destination_root.join("app/controllers/welcome_controller.rb"), <<~RUBY)
      class WelcomeController < AuthenticatedController
        def index
        end
      end
    RUBY

    run_generator default_args

    assert_file "app/controllers/welcome_controller.rb" do |content|
      assert_match(/include Plutonium::Invites::PendingInviteCheck/, content)
      assert_match(/invites_welcome_check_path/, content)
      assert_match(/pending_invite/, content)
      assert_match(/def invite_classes/, content)
      assert_match(/::Invites::OrganizationUserInvite/, content)
    end
  end

  test "skips WelcomeController integration when PendingInviteCheck already present" do
    FileUtils.mkdir_p(destination_root.join("app/controllers"))
    File.write(destination_root.join("app/controllers/welcome_controller.rb"), <<~RUBY)
      class WelcomeController < AuthenticatedController
        include Plutonium::Invites::PendingInviteCheck

        def index
        end
      end
    RUBY

    run_generator default_args

    assert_file "app/controllers/welcome_controller.rb" do |content|
      # Should not duplicate the include
      matches = content.scan("PendingInviteCheck")
      assert_equal 1, matches.length
    end
  end

  test "updates Invites::WelcomeController default_redirect_path when WelcomeController exists" do
    # Create a main WelcomeController
    FileUtils.mkdir_p(destination_root.join("app/controllers"))
    File.write(destination_root.join("app/controllers/welcome_controller.rb"), <<~RUBY)
      class WelcomeController < AuthenticatedController
        def index
        end
      end
    RUBY

    run_generator default_args

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_match(/def default_redirect_path/, content)
      assert_match(/"\/welcome"/, content)
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
      # Should add create_account_redirect
      assert_match(/create_account_redirect "\/welcome"/, content)
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
    content.gsub!("after_login { remember_login }", <<~RUBY.strip)
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

  # --dest option tests

  test "generates entity files in package when dest option provided" do
    # Create entity model, definition, and policy in blogging package with proper markers
    create_package_entity_fixtures("blogging", "Blogging::Post")

    run_generator ["--entity-model=Blogging::Post", "--dest=blogging", "--invite-model=UserInvite"]

    # Entity interaction should be in the package (uses full entity_table path)
    assert_file "packages/blogging/app/interactions/blogging/post/invite_user_interaction.rb" do |content|
      assert_match(/class Blogging::Post::InviteUserInteraction/, content)
      assert_match(/include Plutonium::Invites::Concerns::InviteUser/, content)
    end

    # Invites package files should still be in packages/invites
    # Association name strips shared namespace: Blogging::PostUser + Blogging::Post => :post
    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/belongs_to :post/, content)
      assert_match(/alias_method :entity, :post/, content)
    end
  end

  test "injects association into packaged entity model" do
    create_package_entity_fixtures("blogging", "Blogging::Post")

    run_generator ["--entity-model=Blogging::Post", "--dest=blogging", "--invite-model=UserInvite"]

    assert_file "packages/blogging/app/models/blogging/post.rb" do |content|
      assert_match(/has_many :user_invites, class_name: "Invites::UserInvite"/, content)
    end
  end

  test "injects action into packaged entity definition" do
    create_package_entity_fixtures("blogging", "Blogging::Post")

    run_generator ["--entity-model=Blogging::Post", "--dest=blogging", "--invite-model=UserInvite"]

    assert_file "packages/blogging/app/definitions/blogging/post_definition.rb" do |content|
      assert_match(/action :invite_user/, content)
      assert_match(/Blogging::Post::InviteUserInteraction/, content)
    end
  end

  test "injects policy method into packaged entity policy" do
    create_package_entity_fixtures("blogging", "Blogging::Post")

    run_generator ["--entity-model=Blogging::Post", "--dest=blogging", "--invite-model=UserInvite"]

    assert_file "packages/blogging/app/policies/blogging/post_policy.rb" do |content|
      assert_match(/def invite_user\?/, content)
    end
  end

  test "generates migration with packaged entity reference" do
    create_package_entity_fixtures("blogging", "Blogging::Post")

    run_generator ["--entity-model=Blogging::Post", "--dest=blogging", "--invite-model=UserInvite"]

    # Association name strips shared namespace: Blogging::PostUser + Blogging::Post => :post
    assert_migration "db/migrate/create_user_invites.rb" do |content|
      assert_match(/t\.belongs_to :post/, content)
    end
  end

  test "strips shared namespace from entity association name" do
    # When Competition::TeamUser references Competition::Team,
    # the association should be :team, not :competition_team
    create_package_entity_fixtures("competition", "Competition::Team", membership_model: "Competition::TeamUser")

    run_generator ["--entity-model=Competition::Team", "--membership-model=Competition::TeamUser", "--dest=competition", "--invite-model=UserInvite"]

    # Migration should use :team (stripped namespace)
    assert_migration "db/migrate/create_user_invites.rb" do |content|
      assert_match(/t\.belongs_to :team/, content)
    end

    # Model should use :team for belongs_to
    assert_file "packages/invites/app/models/invites/user_invite.rb" do |content|
      assert_match(/belongs_to :team/, content)
      assert_match(/alias_method :entity, :team/, content)
    end
  end

  # Validation tests

  test "fails when entity model file is missing" do
    # Thor errors are captured by Rails generator test case, so we use assert_raises
    # with the generator instance directly
    generator = Pu::Invites::InstallGenerator.new(
      ["--entity-model=NonExistent::Model", "--dest=fake_package"],
      {},
      destination_root: destination_root
    )

    error = assert_raises(Thor::Error) do
      generator.invoke_all
    end

    assert_match(/Required files missing/, error.message)
    assert_match(/Entity model not found/, error.message)
  end

  test "fails when entity definition file is missing" do
    # Create only the model, not the definition
    FileUtils.mkdir_p(destination_root.join("packages/test_pkg/app/models/test_pkg"))
    File.write(destination_root.join("packages/test_pkg/app/models/test_pkg/entity.rb"), <<~RUBY)
      class TestPkg::Entity < ApplicationRecord
        # add has_many associations above.
      end
    RUBY

    generator = Pu::Invites::InstallGenerator.new(
      ["--entity-model=TestPkg::Entity", "--dest=test_pkg"],
      {},
      destination_root: destination_root
    )

    error = assert_raises(Thor::Error) do
      generator.invoke_all
    end

    assert_match(/Required files missing/, error.message)
    assert_match(/Entity definition not found/, error.message)
  end

  test "fails when entity policy file is missing" do
    # Create model and definition, but not policy
    FileUtils.mkdir_p(destination_root.join("packages/test_pkg/app/models/test_pkg"))
    FileUtils.mkdir_p(destination_root.join("packages/test_pkg/app/definitions/test_pkg"))

    File.write(destination_root.join("packages/test_pkg/app/models/test_pkg/entity.rb"), <<~RUBY)
      class TestPkg::Entity < ApplicationRecord
        # add has_many associations above.
      end
    RUBY
    File.write(destination_root.join("packages/test_pkg/app/definitions/test_pkg/entity_definition.rb"), <<~RUBY)
      class TestPkg::EntityDefinition < Plutonium::Resource::Definition
      end
    RUBY

    generator = Pu::Invites::InstallGenerator.new(
      ["--entity-model=TestPkg::Entity", "--dest=test_pkg"],
      {},
      destination_root: destination_root
    )

    error = assert_raises(Thor::Error) do
      generator.invoke_all
    end

    assert_match(/Required files missing/, error.message)
    assert_match(/Entity policy not found/, error.message)
  end

  test "adds current_membership helper to resource policy" do
    run_generator default_args

    assert_file "app/policies/resource_policy.rb" do |content|
      assert_match(/def current_membership/, content)
      assert_match(/OrganizationUser\.find_by/, content)
      assert_match(/private/, content)
    end
  end

  test "does not duplicate routes on second run" do
    run_generator default_args
    run_generator default_args

    assert_file "config/routes.rb" do |content|
      matches = content.scan('get "invitations/welcome"')
      assert_equal 1, matches.length, "Expected exactly 1 invitations/welcome route, found #{matches.length}"
    end
  end

  test "fails when membership model file is missing" do
    # Create entity model, definition, and policy but no membership model
    FileUtils.mkdir_p(destination_root.join("packages/test_pkg/app/models/test_pkg"))
    FileUtils.mkdir_p(destination_root.join("packages/test_pkg/app/definitions/test_pkg"))
    FileUtils.mkdir_p(destination_root.join("packages/test_pkg/app/policies/test_pkg"))

    File.write(destination_root.join("packages/test_pkg/app/models/test_pkg/entity.rb"), <<~RUBY)
      class TestPkg::Entity < ApplicationRecord
        # add has_many associations above.
      end
    RUBY
    File.write(destination_root.join("packages/test_pkg/app/definitions/test_pkg/entity_definition.rb"), <<~RUBY)
      class TestPkg::EntityDefinition < Plutonium::Resource::Definition
      end
    RUBY
    File.write(destination_root.join("packages/test_pkg/app/policies/test_pkg/entity_policy.rb"), <<~RUBY)
      class TestPkg::EntityPolicy < Plutonium::Resource::Policy
        # Core attributes
      end
    RUBY

    generator = Pu::Invites::InstallGenerator.new(
      ["--entity-model=TestPkg::Entity", "--dest=test_pkg"],
      {},
      destination_root: destination_root
    )

    error = assert_raises(Thor::Error) do
      generator.invoke_all
    end

    assert_match(/Required files missing/, error.message)
    assert_match(/Membership model not found/, error.message)
  end

  test "generates funder invite model with custom invite_model" do
    run_generator default_args + ["--invite-model=FunderInvite"]

    assert_migration "db/migrate/create_funder_invites.rb" do |content|
      assert_match(/class CreateFunderInvites/, content)
      assert_match(/create_table :funder_invites/, content)
    end

    assert_file "packages/invites/app/models/invites/funder_invite.rb" do |content|
      assert_match(/class FunderInvite < Invites::ResourceRecord/, content)
      assert_match(/include Plutonium::Invites::Concerns::InviteToken/, content)
      assert_match(/Invites::FunderInviteMailer/, content)
    end

    assert_file "packages/invites/app/policies/invites/funder_invite_policy.rb" do |content|
      assert_match(/class FunderInvitePolicy/, content)
    end

    assert_file "packages/invites/app/definitions/invites/funder_invite_definition.rb" do |content|
      assert_match(/class FunderInviteDefinition/, content)
      assert_match(/Invites::ResendInviteInteraction/, content)
    end

    assert_file "packages/invites/app/mailers/invites/funder_invite_mailer.rb" do |content|
      assert_match(/class FunderInviteMailer < ApplicationMailer/, content)
      assert_match(/funder_invitation_url\(token:/, content)
    end

    assert_file "packages/invites/app/controllers/invites/funder_invitations_controller.rb" do |content|
      assert_match(/class FunderInvitationsController < ApplicationController/, content)
      assert_match(/::Invites::FunderInvite/, content)
      assert_match(/funder_invitation_path\(token: token\)/, content)
      assert_no_match(/prepend_view_path Invites::Engine/, content)
      assert_match(/rodauth\.login_session\("signup"\)/, content)
    end

    assert_file "packages/invites/app/views/invites/funder_invitations/landing.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invitations/show.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invitations/signup.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invitations/error.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invite_mailer/invitation.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invite_mailer/invitation.text.erb"

    assert_file "app/models/organization.rb" do |content|
      assert_match(/has_many :funder_invites, class_name: "Invites::FunderInvite"/, content)
    end
  end

  private

  test "dual invocation yields independent flows" do
    run_generator default_args  # OrganizationUserInvite (default)
    run_generator default_args + ["--invite-model=FunderInvite"]

    # Both migrations exist, with distinct tables.
    assert_migration "db/migrate/create_organization_user_invites.rb"
    assert_migration "db/migrate/create_funder_invites.rb"

    # Both models, policies, definitions, mailers, controllers exist.
    assert_file "packages/invites/app/models/invites/organization_user_invite.rb"
    assert_file "packages/invites/app/models/invites/funder_invite.rb"
    assert_file "packages/invites/app/policies/invites/organization_user_invite_policy.rb"
    assert_file "packages/invites/app/policies/invites/funder_invite_policy.rb"
    assert_file "packages/invites/app/definitions/invites/organization_user_invite_definition.rb"
    assert_file "packages/invites/app/definitions/invites/funder_invite_definition.rb"
    assert_file "packages/invites/app/mailers/invites/organization_user_invite_mailer.rb"
    assert_file "packages/invites/app/mailers/invites/funder_invite_mailer.rb"
    assert_file "packages/invites/app/controllers/invites/organization_user_invitations_controller.rb"
    assert_file "packages/invites/app/controllers/invites/funder_invitations_controller.rb"

    # Routes contain both helpers + welcome appears exactly once.
    assert_file "config/routes.rb" do |content|
      assert_match(/as: :organization_user_invitation\b/, content)
      assert_match(/as: :funder_invitation\b/, content)
      assert_equal 1, content.scan(/as: :invites_welcome_check\b/).size
    end

    # Entity has has_many for both invite tables.
    assert_file "app/models/organization.rb" do |content|
      assert_match(/has_many :organization_user_invites, class_name: "Invites::OrganizationUserInvite"/, content)
      assert_match(/has_many :funder_invites, class_name: "Invites::FunderInvite"/, content)
    end

    # Welcome controller invite_classes lists both.
    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_match(/::Invites::OrganizationUserInvite/, content)
      assert_match(/::Invites::FunderInvite/, content)
    end
  end

  def create_package_entity_fixtures(package_name, model_name, membership_model: nil)
    # Parse model name: "Blogging::Post" -> table: "blogging/post"
    table_name = model_name.underscore
    membership_model ||= "#{model_name}User"
    membership_table_name = membership_model.underscore

    # Create directories
    model_dir = File.dirname("packages/#{package_name}/app/models/#{table_name}.rb")
    definition_dir = File.dirname("packages/#{package_name}/app/definitions/#{table_name}_definition.rb")
    policy_dir = File.dirname("packages/#{package_name}/app/policies/#{table_name}_policy.rb")
    membership_model_dir = File.dirname("packages/#{package_name}/app/models/#{membership_table_name}.rb")

    FileUtils.mkdir_p(destination_root.join(model_dir))
    FileUtils.mkdir_p(destination_root.join(definition_dir))
    FileUtils.mkdir_p(destination_root.join(policy_dir))
    FileUtils.mkdir_p(destination_root.join(membership_model_dir))

    # Create model with proper markers
    File.write(destination_root.join("packages/#{package_name}/app/models/#{table_name}.rb"), <<~RUBY)
      class #{model_name} < ApplicationRecord
        # add has_many associations above.
      end
    RUBY

    # Create definition
    File.write(destination_root.join("packages/#{package_name}/app/definitions/#{table_name}_definition.rb"), <<~RUBY)
      class #{model_name}Definition < Plutonium::Resource::Definition
      end
    RUBY

    # Create policy with proper markers
    File.write(destination_root.join("packages/#{package_name}/app/policies/#{table_name}_policy.rb"), <<~RUBY)
      class #{model_name}Policy < Plutonium::Resource::Policy
        # Core attributes
      end
    RUBY

    # Create membership model with role enum
    File.write(destination_root.join("packages/#{package_name}/app/models/#{membership_table_name}.rb"), <<~RUBY)
      class #{membership_model} < ApplicationRecord
        enum :role, member: 0, admin: 1
      end
    RUBY
  end
end

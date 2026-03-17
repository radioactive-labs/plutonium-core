# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/saas/welcome_generator"

class SaasWelcomeGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Saas::WelcomeGenerator
  destination Rails.root

  def setup
    git_ensure_clean_dummy_app
    inject_user_entity_association
  end

  def default_args
    ["--user-model=User", "--entity-model=Organization", "--portal=OrgPortal"]
  end

  test "generates authenticated controller with rodauth" do
    run_generator default_args

    assert_file "app/controllers/authenticated_controller.rb" do |content|
      assert_match(/class AuthenticatedController < ApplicationController/, content)
      assert_match(/include Plutonium::Auth::Rodauth\(:user\)/, content)
      assert_match(/rodauth\.require_authentication/, content)
      assert_no_match(/def require_authenticated/, content)
    end
  end

  test "generates welcome controller" do
    run_generator default_args

    assert_file "app/controllers/welcome_controller.rb" do |content|
      assert_match(/class WelcomeController < AuthenticatedController/, content)
      assert_match(/layout "welcome"/, content)
      assert_match(/current_user\.organizations\.to_a/, content)
      assert_match(/Organization\.new/, content)
      assert_match(/OrganizationUser\.create!/, content)
      assert_match(/role: :owner/, content)
    end
  end

  test "generates portal root path helper" do
    run_generator default_args

    assert_file "app/controllers/welcome_controller.rb" do |content|
      assert_match(/OrgPortal::Engine\.routes\.url_helpers\.organization_root_path/, content)
      assert_match(/organization: organization/, content)
      assert_match(/helper_method :portal_root_path/, content)
    end
  end

  test "generates welcome layout" do
    run_generator default_args

    assert_file "app/views/layouts/welcome.html.erb" do |content|
      assert_match(/stylesheet_link_tag/, content)
      assert_match(/yield/, content)
    end
  end

  test "generates onboarding view with fields_for" do
    run_generator default_args

    assert_file "app/views/welcome/onboarding.html.erb" do |content|
      assert_match(/welcome_onboard_path/, content)
      assert_match(/fields_for :organization/, content)
      assert_match(/Workspace Name/, content)
    end
  end

  test "generates select entity view" do
    run_generator default_args

    assert_file "app/views/welcome/select_entity.html.erb" do |content|
      assert_match(/portal_root_path/, content)
      assert_match(/Select a Workspace/, content)
      assert_match(/Create New Workspace/, content)
    end
  end

  test "injects routes" do
    run_generator default_args

    assert_file "config/routes.rb" do |content|
      assert_match(/get "welcome", to: "welcome#index"/, content)
      assert_match(/get "welcome\/onboard"/, content)
      assert_match(/post "welcome\/onboard"/, content)
    end
  end

  test "generates with profile option" do
    run_generator default_args + ["--profile"]

    assert_file "app/controllers/welcome_controller.rb" do |content|
      assert_match(/current_user\.profile/, content)
      assert_match(/profile_params/, content)
    end

    assert_file "app/views/welcome/onboarding.html.erb" do |content|
      assert_match(/fields_for :profile/, content)
      assert_match(/Your Name/, content)
    end
  end

  test "generates without profile by default" do
    run_generator default_args

    assert_file "app/controllers/welcome_controller.rb" do |content|
      assert_no_match(/profile/, content)
    end
  end

  test "generates without rodauth when rodauth is blank" do
    run_generator default_args + ["--rodauth="]

    assert_file "app/controllers/authenticated_controller.rb" do |content|
      assert_no_match(/Plutonium::Auth::Rodauth/, content)
      assert_no_match(/rodauth\.require_authentication/, content)
      assert_match(/before_action :require_authenticated/, content)
      assert_match(/def require_authenticated/, content)
      assert_match(/TODO/, content)
    end
  end

  test "generates with custom membership model" do
    run_generator default_args + ["--membership-model=EntityMembership"]

    assert_file "app/controllers/welcome_controller.rb" do |content|
      assert_match(/EntityMembership\.create!/, content)
    end
  end

  test "generates welcome controller with new_entity action" do
    run_generator default_args

    assert_file "app/controllers/welcome_controller.rb" do |content|
      assert_match(/def new_entity/, content)
      assert_match(/def onboard/, content)
    end
  end

  test "configures rodauth redirects to /welcome" do
    run_generator default_args

    assert_file "app/rodauth/user_rodauth_plugin.rb" do |content|
      assert_match(/login_redirect "\/welcome"/, content)
      assert_match(/create_account_redirect "\/welcome"/, content)
    end
  end

  test "configures rodauth with custom config name" do
    # Create an admin rodauth plugin file
    FileUtils.mkdir_p(destination_root.join("app/rodauth"))
    admin_content = File.read(destination_root.join("app/rodauth/user_rodauth_plugin.rb"))
    admin_content.gsub!("UserRodauthPlugin", "AdminRodauthPlugin")
    File.write(destination_root.join("app/rodauth/admin_rodauth_plugin.rb"), admin_content)

    run_generator default_args + ["--rodauth=admin"]

    assert_file "app/controllers/authenticated_controller.rb" do |content|
      assert_match(/include Plutonium::Auth::Rodauth\(:admin\)/, content)
    end

    assert_file "app/rodauth/admin_rodauth_plugin.rb" do |content|
      assert_match(/login_redirect "\/welcome"/, content)
      assert_match(/create_account_redirect "\/welcome"/, content)
    end
  end

  test "skips rodauth configuration when rodauth is blank" do
    run_generator default_args + ["--rodauth="]

    # Rodauth file should be unchanged
    assert_file "app/rodauth/user_rodauth_plugin.rb" do |content|
      assert_match(/login_redirect "\/"\n/, content)
    end
  end

  test "skips rodauth configuration when plugin file is missing" do
    run_generator default_args + ["--rodauth=nonexistent"]

    # Should not raise, just skip
    assert_file "app/controllers/welcome_controller.rb"
  end

  test "does not duplicate routes on second run" do
    run_generator default_args
    run_generator default_args

    assert_file "config/routes.rb" do |content|
      matches = content.scan('get "welcome", to: "welcome#index"')
      assert_equal 1, matches.length, "Expected exactly 1 welcome route, found #{matches.length}"
    end
  end

  test "removes standalone invites welcome route if present" do
    # Simulate the invites generator having added a standalone welcome route
    inject_invites_welcome_route

    run_generator default_args

    assert_file "config/routes.rb" do |content|
      assert_no_match(/invites\/welcome#index/, content)
      assert_match(/get "welcome", to: "welcome#index"/, content)
    end
  end

  test "integrates with existing invites routes" do
    # Simulate the invites generator having added routes and standalone welcome
    inject_invites_welcome_route
    inject_invites_invitation_routes

    run_generator default_args

    assert_file "config/routes.rb" do |content|
      # Standalone invites welcome route should be removed
      assert_no_match(/invites\/welcome#index/, content)
      # Main welcome route should exist
      assert_match(/get "welcome", to: "welcome#index"/, content)
      # Invites routes should still be intact
      assert_match(/get "invitations\/:token"/, content)
    end
  end

  test "fails when user model is missing" do
    generator = Pu::Saas::WelcomeGenerator.new(
      [],
      {user_model: "NonExistent", entity_model: "Organization", portal: "OrgPortal"},
      destination_root: destination_root
    )

    error = assert_raises(Thor::Error) do
      generator.invoke_all
    end

    assert_match(/Required files missing/, error.message)
    assert_match(/User model not found/, error.message)
  end

  test "fails when entity model is missing" do
    generator = Pu::Saas::WelcomeGenerator.new(
      [],
      {user_model: "User", entity_model: "NonExistent", portal: "OrgPortal"},
      destination_root: destination_root
    )

    error = assert_raises(Thor::Error) do
      generator.invoke_all
    end

    assert_match(/Required files missing/, error.message)
    assert_match(/Entity model not found/, error.message)
  end

  test "fails when user model missing entity association" do
    # Remove the association we injected in setup
    user_file = Rails.root.join("app/models/user.rb")
    content = File.read(user_file)
    content.gsub!("  has_many :organizations, through: :organization_users\n", "")
    File.write(user_file, content)

    generator = Pu::Saas::WelcomeGenerator.new(
      [],
      {user_model: "User", entity_model: "Organization", portal: "OrgPortal"},
      destination_root: destination_root
    )

    error = assert_raises(Thor::Error) do
      generator.invoke_all
    end

    assert_match(/Required files missing/, error.message)
    assert_match(/has_many :organizations/, error.message)
  end

  private

  def inject_user_entity_association
    user_file = Rails.root.join("app/models/user.rb")
    content = File.read(user_file)
    return if content.include?("has_many :organizations")

    content.sub!(
      "# add has_many associations above.",
      "has_many :organizations, through: :organization_users\n  # add has_many associations above."
    )
    File.write(user_file, content)
  end

  def inject_invites_welcome_route
    routes_file = Rails.root.join("config/routes.rb")
    content = File.read(routes_file)
    invites_welcome = <<~RUBY.chomp

      # Welcome route (handled by invites package — replace with pu:saas:welcome for full onboarding)
      get "welcome", to: "invites/welcome#index"
    RUBY
    content.sub!(/^end\s*\z/, "#{invites_welcome}\nend\n")
    File.write(routes_file, content)
  end

  def inject_invites_invitation_routes
    routes_file = Rails.root.join("config/routes.rb")
    content = File.read(routes_file)
    invites_routes = <<~RUBY.chomp

      # User invitation routes
      scope module: :invites do
        get "invitations/welcome", to: "welcome#index", as: :invites_welcome_check
        delete "invitations/welcome", to: "welcome#skip", as: :invites_welcome_skip
        get "invitations/:token", to: "user_invitations#show", as: :invitation
        post "invitations/:token/accept", to: "user_invitations#accept", as: :accept_invitation
        get "invitations/:token/signup", to: "user_invitations#signup", as: :invitation_signup
        post "invitations/:token/signup", to: "user_invitations#signup"
      end
    RUBY
    content.sub!(/^end\s*\z/, "#{invites_routes}\nend\n")
    File.write(routes_file, content)
  end
end

# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/active_record/migration"
require_relative "../lib/plutonium_generators"

module Pu
  module Invites
    class InstallGenerator < ::Rails::Generators::Base
      include ::ActiveRecord::Generators::Migration
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::RodauthRedirects

      source_root File.expand_path("templates", __dir__)

      desc "Install user invites package"

      class_option :entity_model, type: :string, default: "Entity",
        desc: "The entity model name for scoping invites"

      class_option :user_model, type: :string, default: "User",
        desc: "The user model name"

      class_option :invite_model, type: :string, default: nil,
        desc: "The invite model class name. Defaults to <EntityModel><UserModel>Invite (e.g., OrganizationUserInvite). Override for separate flows in multi-entity apps."

      class_option :membership_model, type: :string,
        desc: "The membership model name (defaults to <Entity><User>)"

      class_option :rodauth, type: :string, default: "user",
        desc: "Rodauth configuration name for signup integration"

      class_option :enforce_domain, type: :boolean, default: false,
        desc: "Require invited user email to match entity domain"

      class_option :dest, type: :string, default: "main_app",
        desc: "Package where entity model is located (default: main_app)"

      def validate_requirements
        errors = []

        unless File.exist?(Rails.root.join(entity_model_path))
          errors << "Entity model not found: #{entity_model_path}"
        end

        unless File.exist?(Rails.root.join(entity_definition_path))
          errors << "Entity definition not found: #{entity_definition_path}"
        end

        unless File.exist?(Rails.root.join(entity_policy_path))
          errors << "Entity policy not found: #{entity_policy_path}"
        end

        unless File.exist?(Rails.root.join(user_definition_path))
          errors << "User definition not found: #{user_definition_path}"
        end

        unless File.exist?(Rails.root.join(user_policy_path))
          errors << "User policy not found: #{user_policy_path}"
        end

        unless File.exist?(membership_model_file)
          errors << "Membership model not found: #{membership_model_file.relative_path_from(Rails.root)}"
        end

        if errors.any?
          errors.each { |e| say_status :error, e, :red }
          raise Thor::Error, "Required files missing:\n  - #{errors.join("\n  - ")}"
        end
      end

      def create_package
        generate "pu:pkg:package", "invites"
      end

      def create_user_invites_migration
        migration_template "db/migrate/create_user_invites.rb",
          "db/migrate/create_#{invite_table}.rb"
      end

      def create_model
        template "packages/invites/app/models/invites/user_invite.rb",
          "packages/invites/app/models/invites/#{invite_underscore}.rb"
      end

      def create_mailer
        template "packages/invites/app/mailers/invites/user_invite_mailer.rb",
          "packages/invites/app/mailers/invites/#{invite_underscore}_mailer.rb"

        template "packages/invites/app/views/invites/user_invite_mailer/invitation.html.erb",
          "packages/invites/app/views/invites/#{invite_underscore}_mailer/invitation.html.erb"

        template "packages/invites/app/views/invites/user_invite_mailer/invitation.text.erb",
          "packages/invites/app/views/invites/#{invite_underscore}_mailer/invitation.text.erb"
      end

      def create_controllers
        template "packages/invites/app/controllers/invites/user_invitations_controller.rb",
          "packages/invites/app/controllers/invites/#{invitations_path}_controller.rb"

        # Welcome controller is a one-shot — only generate if it doesn't exist yet.
        welcome_path = "packages/invites/app/controllers/invites/welcome_controller.rb"
        unless File.exist?(Rails.root.join(welcome_path))
          template "packages/invites/app/controllers/invites/welcome_controller.rb",
            welcome_path
        end
      end

      def add_welcome_invite_class
        welcome_path = "packages/invites/app/controllers/invites/welcome_controller.rb"
        return unless File.exist?(Rails.root.join(welcome_path))

        content = File.read(Rails.root.join(welcome_path))
        new_class = "::Invites::#{invite_model}"

        # Already present? bail. Use a non-word lookahead so we don't match
        # `::Invites::FunderInvite` when looking for `::Invites::Funder`.
        return if content =~ /#{Regexp.escape(new_class)}(?!\w)/

        # Find `def invite_classes` block; inject before the closing `]`.
        injection = content.sub(/(\bdef invite_classes\b.*?\[)([^\]]*)(\])/m) do
          before, list, after = Regexp.last_match[1], Regexp.last_match[2], Regexp.last_match[3]
          existing = list.strip
          new_list = existing.empty? ? new_class : "#{existing.chomp(",").strip}, #{new_class}"
          "#{before}#{new_list}#{after}"
        end

        if injection != content
          File.write(Rails.root.join(welcome_path), injection)
          say_status :inject, "Added #{new_class} to welcome controller's invite_classes", :green
        end
      end

      def create_views
        %w[landing show signup error].each do |view|
          template "packages/invites/app/views/invites/user_invitations/#{view}.html.erb",
            "packages/invites/app/views/invites/#{invitations_path}/#{view}.html.erb"
        end

        # Welcome view is a one-shot too.
        pending_path = "packages/invites/app/views/invites/welcome/pending_invitation.html.erb"
        unless File.exist?(Rails.root.join(pending_path))
          template "packages/invites/app/views/invites/welcome/pending_invitation.html.erb",
            pending_path
        end

        layout_path = "packages/invites/app/views/layouts/invites/invitation.html.erb"
        unless File.exist?(Rails.root.join(layout_path))
          template "packages/invites/app/views/layouts/invites/invitation.html.erb",
            layout_path
        end
      end

      def create_interactions
        template "packages/invites/app/interactions/invites/resend_invite_interaction.rb",
          "packages/invites/app/interactions/invites/resend_invite_interaction.rb"

        template "packages/invites/app/interactions/invites/cancel_invite_interaction.rb",
          "packages/invites/app/interactions/invites/cancel_invite_interaction.rb"
      end

      def create_definition
        template "packages/invites/app/definitions/invites/user_invite_definition.rb",
          "packages/invites/app/definitions/invites/#{invite_underscore}_definition.rb"
      end

      def create_policy
        template "packages/invites/app/policies/invites/user_invite_policy.rb",
          "packages/invites/app/policies/invites/#{invite_underscore}_policy.rb"
      end

      def add_entity_association
        inject_into_file entity_model_path,
          "  has_many :#{invite_table}, class_name: \"Invites::#{invite_model}\", dependent: :destroy\n",
          before: /^\s*# add has_many associations above\.\n/
      end

      def create_entity_interaction
        dest_path = if entity_in_package?
          "packages/#{entity_package}/app/interactions/#{entity_table}/invite_user_interaction.rb"
        else
          "app/interactions/#{entity_table}/invite_user_interaction.rb"
        end

        template "app/interactions/invite_user_interaction.rb", dest_path
      end

      def add_entity_action
        inject_into_file entity_definition_path,
          "  action :invite_user, interaction: #{entity_model}::InviteUserInteraction, category: :secondary\n",
          after: /class #{entity_model}Definition < .+\n/
      end

      def add_entity_policy
        inject_into_file entity_policy_path,
          "def invite_user?\n    current_membership&.owner?\n  end\n\n  ",
          before: "# Core attributes"
      end

      def create_user_interaction
        template "app/interactions/user_invite_user_interaction.rb",
          "app/interactions/#{user_table}/invite_user_interaction.rb"
      end

      def add_user_action
        inject_into_file user_definition_path,
          "  action :invite_user, interaction: #{user_model}::InviteUserInteraction, category: :primary\n",
          after: /class #{user_model}Definition < .+\n/
      end

      def add_user_policy
        inject_into_file user_policy_path,
          "def invite_user?\n    current_membership&.owner?\n  end\n\n  ",
          before: "# Core attributes"
      end

      def add_resource_policy_helper
        resource_policy_path = "app/policies/resource_policy.rb"

        return unless File.exist?(Rails.root.join(resource_policy_path))

        file_content = File.read(Rails.root.join(resource_policy_path))

        helper_code = <<-RUBY
  def current_membership
    return unless entity_scope && user

    @current_membership ||= #{membership_model}.find_by(#{entity_association_name}: entity_scope, #{user_association_name}: user)
  end
        RUBY

        if file_content.include?("private\n")
          inject_into_file resource_policy_path,
            "\n#{helper_code}",
            after: "private\n"
        else
          inject_into_file resource_policy_path,
            "\n  private\n\n#{helper_code}",
            before: /^end\s*\z/
        end
      end

      def add_routes
        routes_content = File.read(Rails.root.join("config/routes.rb"))
        flow_marker = "# Invitation routes for #{invite_model}"

        if routes_content.include?(flow_marker)
          say_status :skip, "Invitation routes for #{invite_model} already present", :yellow
        else
          welcome_present = routes_content.include?("# Invitation welcome routes")

          welcome_block = if welcome_present
            ""
          else
            <<-RUBY

  # Invitation welcome routes (shared across all invite flows)
  scope module: :invites do
    get "invitations/welcome", to: "welcome#index", as: :invites_welcome_check
    delete "invitations/welcome", to: "welcome#skip", as: :invites_welcome_skip
  end
            RUBY
          end

          flow_block = <<-RUBY

  #{flow_marker}
  scope module: :invites do
    get "#{invitations_path}/:token", to: "#{invitations_path}#show", as: :#{invite_route_prefix}_invitation
    post "#{invitations_path}/:token/accept", to: "#{invitations_path}#accept", as: :accept_#{invite_route_prefix}_invitation
    get "#{invitations_path}/:token/signup", to: "#{invitations_path}#signup", as: :#{invite_route_prefix}_invitation_signup
    post "#{invitations_path}/:token/signup", to: "#{invitations_path}#signup"
  end
          RUBY

          inject_into_file "config/routes.rb",
            welcome_block + flow_block,
            before: /^end\s*\z/
        end

        # If no main WelcomeController exists, add /welcome route pointing to
        # Invites::WelcomeController so Rodauth's login_redirect "/welcome" works.
        routes_content = File.read(Rails.root.join("config/routes.rb"))
        unless File.exist?(Rails.root.join("app/controllers/welcome_controller.rb")) ||
            routes_content.include?(%(get "welcome", to: "invites/welcome#index"))
          welcome_route = <<-RUBY

  # Welcome route (handled by invites package — replace with pu:saas:welcome for full onboarding)
  get "welcome", to: "invites/welcome#index"
          RUBY

          inject_into_file "config/routes.rb",
            welcome_route,
            before: /^\s*# Invitation welcome routes/
        end
      end

      def configure_rodauth
        return unless rodauth?

        rodauth_file = "app/rodauth/#{rodauth_config}_rodauth_plugin.rb"

        unless File.exist?(Rails.root.join(rodauth_file))
          say_status :skip, "Rodauth plugin not found: #{rodauth_file}", :yellow
          return
        end

        file_content = File.read(Rails.root.join(rodauth_file))

        # Check if already configured
        if file_content.include?("after_welcome_redirect")
          say_status :skip, "Rodauth already configured for invites", :yellow
          return
        end

        # Check for existing after_login block (non-commented)
        # Single-line: after_login { remember_login }
        single_line_match = file_content.match(/^(\s*)after_login\s*\{\s*(.+?)\s*\}/)
        # Multi-line: after_login do ... end
        multi_line_match = file_content.match(/^(\s*)after_login\s+do\s*\n(.*?)\n(\s*)end/m)

        if single_line_match
          # Convert single-line block to multi-line with our code added
          indent = single_line_match[1]
          existing_code = single_line_match[2]
          original_line = single_line_match[0]

          new_block = <<~RUBY.chomp
            #{indent}after_login do
            #{indent}  #{existing_code}
            #{indent}  session[:after_welcome_redirect] = session.delete(:login_redirect)
            #{indent}end
          RUBY

          gsub_file rodauth_file, original_line, new_block
          say_status :info, "Added session redirect to existing after_login block", :green
        elsif multi_line_match
          # Multi-line block - add our line before the end
          indent = multi_line_match[1]
          block_content = multi_line_match[2]
          end_indent = multi_line_match[3]
          original_block = multi_line_match[0]

          new_block = <<~RUBY.chomp
            #{indent}after_login do
            #{block_content}
            #{indent}  session[:after_welcome_redirect] = session.delete(:login_redirect)
            #{end_indent}end
          RUBY

          gsub_file rodauth_file, original_block, new_block
          say_status :info, "Added session redirect to existing after_login block", :green
        else
          # Add new after_login block
          after_login_code = <<-RUBY

    # ==> User Invites - Move captured path to session for WelcomeController
    after_login do
      session[:after_welcome_redirect] = session.delete(:login_redirect)
    end
          RUBY

          inject_into_file rodauth_file,
            after_login_code,
            before: /^  end\s*\n/

          say_status :info, "Added after_login block for invites", :green
        end

        # Add other config options if not present
        unless file_content.include?("login_return_to_requested_location?")
          inject_into_file rodauth_file,
            "\n    # Enable path capture so Rodauth stores the originally requested URL\n    login_return_to_requested_location? true\n",
            after: /login_redirect.*\n/
        end

        # Update login_redirect and create_account_redirect to /welcome
        update_rodauth_redirects(rodauth_file)
      end

      def integrate_with_welcome_controller
        welcome_controller_path = Rails.root.join("app/controllers/welcome_controller.rb")
        return unless File.exist?(welcome_controller_path)

        file_content = File.read(welcome_controller_path)
        return if file_content.include?("PendingInviteCheck")

        relative_path = "app/controllers/welcome_controller.rb"

        # Add PendingInviteCheck concern and invites view path
        inject_into_file relative_path,
          "  include Plutonium::Invites::PendingInviteCheck\n\n  prepend_view_path Invites::Engine.root.join(\"app/views\")\n",
          after: /class WelcomeController.*\n/

        # Add invite check as first step in index
        inject_into_file relative_path,
          "    return redirect_to(invites_welcome_check_path) if pending_invite\n\n",
          after: /def index\n/

        # Add invite_classes method if neither it nor invite_class is present
        if file_content !~ /def invite_classes\b/ && file_content !~ /def invite_class\b/
          inject_into_file relative_path,
            "\n  def invite_classes\n    [::Invites::#{invite_model}]\n  end\n",
            before: /^end\s*\z/
        else
          # Inject this invite_model into the existing invite_classes array if missing.
          host_content = File.read(Rails.root.join(relative_path))
          if host_content =~ /def invite_classes\b/ && host_content !~ /::Invites::#{invite_model}\b/
            updated = host_content.sub(/(\bdef invite_classes\b.*?\[)([^\]]*)(\])/m) do
              before, list, after = Regexp.last_match[1], Regexp.last_match[2], Regexp.last_match[3]
              existing = list.strip
              new_list = existing.empty? ? "::Invites::#{invite_model}" : "#{existing.chomp(",").strip}, ::Invites::#{invite_model}"
              "#{before}#{new_list}#{after}"
            end
            File.write(Rails.root.join(relative_path), updated)
          end
        end

        # Update Invites::WelcomeController to redirect to /welcome (the main hub)
        # instead of / (the app root)
        invites_welcome_path = "packages/invites/app/controllers/invites/welcome_controller.rb"
        if File.exist?(Rails.root.join(invites_welcome_path))
          gsub_file invites_welcome_path,
            /def default_redirect_path\n\s*"\/"\n\s*end/,
            "def default_redirect_path\n      \"/welcome\"\n    end"
        end

        say_status :info, "Integrated invite check into WelcomeController", :green
      end

      def show_instructions
        readme "INSTRUCTIONS" if behavior == :invoke
      end

      private

      def entity_model
        options[:entity_model].camelize
      end

      def entity_table
        options[:entity_model].underscore
      end

      # Returns the association name for entity on the membership model.
      # Strips shared namespace between membership and entity models.
      # e.g., Competition::TeamUser -> Competition::Team uses :team (not :competition_team)
      def entity_association_name
        PlutoniumGenerators::Generator.derive_association_name(membership_model, entity_model)
      end

      # Returns the association name for user on the membership model.
      # Same logic as entity_association_name but for the user side.
      # e.g., RestaurantStaffUser -> StaffUser uses :staff_user (not :user)
      def user_association_name
        PlutoniumGenerators::Generator.derive_association_name(membership_model, user_model)
      end

      def entity_in_package?
        options[:dest] != "main_app"
      end

      def entity_package
        options[:dest]
      end

      def entity_model_path
        if entity_in_package?
          "packages/#{entity_package}/app/models/#{entity_table}.rb"
        else
          "app/models/#{entity_table}.rb"
        end
      end

      def entity_definition_path
        if entity_in_package?
          "packages/#{entity_package}/app/definitions/#{entity_table}_definition.rb"
        else
          "app/definitions/#{entity_table}_definition.rb"
        end
      end

      def entity_policy_path
        if entity_in_package?
          "packages/#{entity_package}/app/policies/#{entity_table}_policy.rb"
        else
          "app/policies/#{entity_table}_policy.rb"
        end
      end

      def user_model
        options[:user_model].camelize
      end

      def user_table
        options[:user_model].underscore
      end

      def user_definition_path
        "app/definitions/#{user_table}_definition.rb"
      end

      def user_policy_path
        "app/policies/#{user_table}_policy.rb"
      end

      def invite_model
        return options[:invite_model].camelize if options[:invite_model].present?

        # Flatten "::" so namespaced entities like Blogging::Post produce a
        # valid (single-segment) class name: BloggingPostUserInvite.
        entity_part = entity_model.delete(":")
        user_part = user_model.delete(":")
        "#{entity_part}#{user_part}Invite"
      end

      def invite_underscore
        invite_model.underscore
      end

      def invite_table
        invite_model.tableize
      end

      # e.g. UserInvite -> UserInvitationsController, FunderInvite -> FunderInvitationsController.
      # If the input ends in "Invite", swap to "Invitations"; else append "Invitations".
      def invitations_controller_class
        base = invite_model.sub(/Invite\z/, "")
        "#{base}InvitationsController"
      end

      def invitations_path
        invitations_controller_class.sub(/Controller\z/, "").underscore
      end

      # Route helper prefix: "user" for UserInvite, "funder" for FunderInvite.
      def invite_route_prefix
        invite_model.sub(/Invite\z/, "").underscore.presence || "invite"
      end

      def membership_model
        options[:membership_model] || "#{entity_model}#{user_model}"
      end

      def membership_model_file
        model_path = "#{membership_model.underscore}.rb"
        if entity_in_package?
          Rails.root.join("packages", entity_package, "app/models", model_path)
        else
          Rails.root.join("app/models", model_path)
        end
      end

      # Read roles from the membership model's enum definition
      def roles
        content = File.read(membership_model_file)
        if (match = content.match(/enum\s+:role,\s*(.+?)(?:\n|$)/))
          match[1].scan(/(\w+):/).flatten
        else
          raise Thor::Error, "Could not find 'enum :role' in #{membership_model_file.relative_path_from(Rails.root)}"
        end
      end

      def rodauth_config
        options[:rodauth]
      end

      def rodauth?
        rodauth_config.present?
      end

      def enforce_domain?
        options[:enforce_domain]
      end
    end
  end
end

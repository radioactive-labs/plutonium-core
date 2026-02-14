return unless defined?(Rodauth::Rails)

require "rails/generators/base"

require_relative "../lib/plutonium_generators"

module Pu
  module Rodauth
    class AdminGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Concerns::Logger

      source_root "#{__dir__}/templates"

      desc "Generate a rodauth-rails account optimized for performing admin tasks"

      argument :name

      class_option :roles, type: :array, default: %w[super_admin admin],
        desc: "Available roles for admin accounts"

      class_option :extra_attributes, type: :array, default: [],
        desc: "Additional attributes to add to the account model (e.g., name:string)"

      def start
        generate_admin_account
        configure_admin_account
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def generate_admin_account
        invoke "pu:rodauth:account", [name],
          defaults: false,
          **admin_features,
          extra_attributes: options[:extra_attributes],
          force: options[:force],
          skip: options[:skip]
      end

      def configure_admin_account
        add_role_column_to_migration
        # Prevent account creation from web
        insert_into_file "app/rodauth/#{normalized_name}_rodauth_plugin.rb", indent(<<~EOT, 4), after: /# ==> Hooks\n/

          # Prevent using the web to sign up.
          before_create_account_route do
            request.halt unless internal_request?
          end

        EOT

        # Customize login flow
        insert_into_file "app/rodauth/#{normalized_name}_rodauth_plugin.rb", indent(<<~EOT, 4), before: /\n.*# ==> Emails/

          # Only ask for password after asking for the login
          use_multi_phase_login? true
        EOT

        # Configure MFA return
        gsub_file(
          "app/rodauth/#{normalized_name}_rodauth_plugin.rb",
          /.*two_factor_auth_return_to_requested_location?.*/,
          indent("two_factor_auth_return_to_requested_location? true", 4),
          verbose: false
        )

        # Configure MFA flash message
        insert_into_file "app/rodauth/#{normalized_name}_rodauth_plugin.rb", indent(<<~EOT, 4), after: /# Override default flash messages.*\n/
          two_factor_not_setup_error_flash "You need to setup two factor authentication"
        EOT

        template "app/views/_login_form_footer.html.erb.tt", "app/views/rodauth/#{normalized_name}/_login_form_footer.html.erb"

        template "lib/tasks/rodauth_admin.rake", "lib/tasks/rodauth_#{normalized_name}.rake"

        add_role_enum
        create_invite_interaction
      end

      def add_role_column_to_migration
        migration_file = Dir[File.join(destination_root, "db/migrate/*_create_rodauth_#{normalized_name}_*.rb")].first
        return unless migration_file

        inject_into_file migration_file,
          "      t.integer :role, null: false, default: 0\n",
          after: /t\.string :password_hash\n/
      end

      def add_role_enum
        inject_into_file "app/models/#{normalized_name}.rb",
          "enum :role, #{roles_enum}\n  ",
          before: "# add enums above.\n"
      end

      def create_invite_interaction
        template "app/interactions/invite_admin_interaction.rb",
          "app/interactions/#{normalized_name}/invite_interaction.rb"

        inject_into_file "app/definitions/#{normalized_name}_definition.rb",
          "  action :invite, interaction: #{name.classify}::InviteInteraction, collection: true, category: :primary\n",
          after: /class #{name.classify}Definition < .+\n/

        inject_into_file "app/policies/#{normalized_name}_policy.rb",
          "def invite?\n    true\n  end\n\n  ",
          before: "# Core attributes"
      end

      def admin_features
        [
          :login, :remember, :logout,
          :create_account, :verify_account, :close_account,
          :reset_password, :reset_password_notify, :change_password,
          :otp, :recovery_codes,
          :lockout, :active_sessions, :audit_logging,
          :password_grace_period,
          :internal_request
        ].map { |feature| [feature, true] }.to_h
      end

      def display_name = name.underscore.humanize.downcase

      def normalized_name = name.underscore

      def roles
        Array(options[:roles]).flat_map { |r| r.split(",") }.map(&:strip)
      end

      def roles_enum
        roles.each_with_index.map { |r, i| "#{r}: #{i}" }.join(", ")
      end

      def default_role
        [1, roles.size - 1].min
      end

      def default_role_name
        roles[default_role]
      end
    end
  end
end

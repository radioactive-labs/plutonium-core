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
          force: options[:force],
          skip: options[:skip]
      end

      def configure_admin_account
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

      def display_name = name.humanize.downcase

      def normalized_name = name.underscore
    end
  end
end

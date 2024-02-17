return unless defined?(Rodauth::Rails)

require "rails/generators/base"
require "securerandom"

require "#{__dir__}/concerns/configuration"
require "#{__dir__}/concerns/account_selector"
require "#{__dir__}/concerns/feature_selector"

module Pu
  module Rodauth
    class AccountGenerator < ::Rails::Generators::Base
      include Concerns::AccountSelector
      include Concerns::FeatureSelector

      source_root "#{__dir__}/templates"

      desc "Generate a rodauth-rails account.\n\n" \
           "Configures a basic set of features as well as migrations, a model, mailer and views."

      def install_dependencies
        Bundler.with_unbundled_env do
          run "bundle add jwt" if jwt? || jwt_refresh?
          run "bundle add rotp" if otp?
          run "bundle add rqrcode" if otp?
          run "bundle add webauthn" if webauthn? || webauthn_autofill?
        end
      end

      def create_rodauth_app
        template "app/misc/account_rodauth_plugin.rb", "app/misc/#{table_prefix}_rodauth_plugin.rb"
      end

      def configure_rodauth_plugin
        in_root do
          plugin_name = indent(
            "configure ::#{table_prefix.classify}RodauthPlugin#{", :#{table_prefix}" unless primary?}\n", 2
          )
          gsub_file "app/misc/rodauth_app.rb", /.*# configure RodauthMain\n/, ""
          insert_into_file "app/misc/rodauth_app.rb", plugin_name, after: "# auth configuration\n"
        end
      end

      def configure_rodauth_plugin_load_route
        in_root do
          route_config = indent("r.rodauth#{"(:#{table_prefix})" unless primary?}\n", 4)
          gsub_file "app/misc/rodauth_app.rb", /.*# r\.rodauth\n/, ""
          insert_into_file "app/misc/rodauth_app.rb", route_config, after: "# auth route configuration\n"
        end
      end

      def configure_rodauth_plugin_load_memory
        in_root do
          plugin_config = indent(
            "rodauth#{"(:#{table_prefix})" unless primary?}.load_memory # autologin remembered #{table}\n", 4
          )
          gsub_file "app/misc/rodauth_app.rb", /.*# rodauth\.load_memory.*\n/, ""

          if remember?
            insert_into_file "app/misc/rodauth_app.rb", plugin_config, after: "# plugin route configuration\n"
          else
            gsub_file "app/misc/rodauth_app.rb", plugin_config, ""
            in_root do
              unless File.read("app/misc/rodauth_app.rb").match?(/.*\.load_memory # autologin/)
                insert_into_file "app/misc/rodauth_app.rb", indent("# rodauth.load_memory # autologin remembered users\n", 4),
                  after: "# plugin route configuration\n"
              end
            end
          end
        end
      end

      def create_rodauth_controller
        dest = "app/controllers/rodauth/#{table_prefix}_controller.rb"
        template "app/controllers/plugin_controller.rb", dest
      end

      def generate_rodauth_migration
        return if selected_migration_features.empty?

        invoke "pu:rodauth:migration", [table], features: selected_migration_features,
          name: kitchen_sink? ? "rodauth_kitchen_sink" : nil,
          migration_name: options[:migration_name],
          force: options[:force],
          skip: options[:skip]
      end

      def create_account_model
        return unless base?

        template "app/models/account.rb", "app/models/#{table_prefix}.rb"
      end

      def create_mailer
        return unless mails?

        template "app/mailers/rodauth_mailer.rb", "app/mailers/rodauth_mailer.rb"
        template "app/mailers/account_mailer.rb", "app/mailers/rodauth/#{table_prefix}_mailer.rb"
        directory "app/views/rodauth_mailer", "app/views/rodauth/#{table_prefix}_mailer"
      end

      def create_views
        return if only_json? || selected_view_features.empty?

        account_name = primary? ? nil : table_prefix
        # Use generate here because invoke spawns in the same process
        # Unfortunately, during the generation process, some new files are created which are not currently loaded,
        #   causing an error when it attempts to load the rodauth config.
        # Generate spawns a separate process which loads the new files and ensures it works correctly
        generate "pu:rodauth:views", account_name, "--features", *selected_view_features
      end

      private

      def only_json?
        ::Rails.application.config.api_only || !::Rails.application.config.session_store || options[:api_only]
      end
    end
  end
end

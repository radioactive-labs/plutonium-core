require "rails/generators/base"
require "securerandom"

require "#{__dir__}/concerns/configuration"
require "#{__dir__}/concerns/account_selector"
require "#{__dir__}/concerns/feature_selector"
require "#{__dir__}/../lib/plutonium_generators/concerns/actions"

module Pu
  module Rodauth
    class AccountGenerator < ::Rails::Generators::Base
      include Concerns::AccountSelector
      include Concerns::FeatureSelector
      include PlutoniumGenerators::Concerns::Actions

      source_root "#{__dir__}/templates"

      desc "Generate a rodauth-rails account.\n\n" \
           "Configures a basic set of features as well as migrations, a model, mailer and views."

      class_option :extra_attributes, type: :array, default: [],
        desc: "Additional attributes to add to the account model (e.g., role:integer)"

      class_option :login_column, type: :string, default: "email",
        desc: "Name of the login column (default: email)"

      def install_dependencies
        gems = []
        gems << "jwt" if jwt? || jwt_refresh?
        gems << "rotp" if otp?
        gems << "rqrcode" if otp?
        gems << "webauthn" if webauthn? || webauthn_autofill?
        gems = gems.reject { |g| gem_in_bundle?(g) }
        return if gems.empty?

        Bundler.with_unbundled_env do
          gems.each { |gem| run "bundle add #{gem}" }
        end
      end

      def create_rodauth_app
        template "app/rodauth/account_rodauth_plugin.rb", "app/rodauth/#{account_path}_rodauth_plugin.rb"
      end

      def configure_rodauth_plugin
        in_root do
          plugin_name = indent(
            "configure ::#{account_path.classify}RodauthPlugin#{", :#{table_prefix}" unless primary?}\n", 2
          )
          gsub_file "app/rodauth/rodauth_app.rb", /.*# configure RodauthMain\n/, ""
          insert_into_file "app/rodauth/rodauth_app.rb", plugin_name, after: "# auth configuration\n"
        end
      end

      def configure_rodauth_plugin_load_route
        in_root do
          route_config = indent("r.rodauth#{"(:#{table_prefix})" unless primary?}\n", 4)
          gsub_file "app/rodauth/rodauth_app.rb", /.*# r\.rodauth\n/, ""
          insert_into_file "app/rodauth/rodauth_app.rb", route_config, after: "# auth route configuration\n"
        end
      end

      def configure_rodauth_plugin_load_memory
        in_root do
          rodauth_app = File.read("app/rodauth/rodauth_app.rb")
          load_memory_pattern = primary? ? /rodauth\.load_memory/ : /rodauth\(:#{table_prefix}\)\.load_memory/

          return if rodauth_app.match?(load_memory_pattern)

          plugin_config = if primary?
            indent("rodauth.load_memory # autologin remembered #{table}\n", 4)
          else
            indent(<<~RUBY, 4)
              if r.path.start_with?("/#{table_prefix}_dashboard")
                rodauth(:#{table_prefix}).load_memory # autologin remembered #{table}
              end
            RUBY
          end

          if remember?
            insert_into_file "app/rodauth/rodauth_app.rb", plugin_config, after: "# plugin route configuration\n"
          else
            unless rodauth_app.match?(/\.load_memory # autologin/)
              insert_into_file "app/rodauth/rodauth_app.rb", indent("# rodauth.load_memory # autologin remembered users\n", 4),
                after: "# plugin route configuration\n"
            end
          end
        end
      end

      def create_rodauth_controller
        dest = "app/controllers/rodauth/#{account_path}_controller.rb"
        template "app/controllers/plugin_controller.rb", dest
      end

      def generate_rodauth_migration
        return if selected_migration_features.empty?

        invoke "pu:rodauth:migration", [table], features: selected_migration_features,
          name: kitchen_sink? ? "rodauth_kitchen_sink" : nil,
          migration_name: options[:migration_name],
          login_column: login_column,
          force: options[:force],
          skip: options[:skip]

        add_extra_columns_to_migration
      end

      def add_extra_columns_to_migration
        return if options[:extra_attributes].blank?

        migration_file = Dir[File.join(destination_root, "db/migrate/*_create_rodauth_#{table_prefix}_*.rb")].first
        return unless migration_file

        attributes = options[:extra_attributes].map { |attr| PlutoniumGenerators::ModelGeneratorBase::GeneratedAttribute.parse(table, attr) }
        columns = attributes.map { |a| "      t.#{a.type} :#{a.name}#{a.inject_options}" }.join("\n")

        inject_into_file migration_file, "#{columns}\n", after: /t\.string :password_hash\n/
      end

      def create_account_model
        return unless base?

        template "app/models/account.rb", "app/models/#{account_path}.rb"
        scaffold_attrs = ["#{login_column}:string", "status:integer"] + Array(options[:extra_attributes])
        invoke "pu:res:scaffold", [table, *scaffold_attrs], dest: "main_app",
          model: false,
          force: true,
          skip: options[:skip]
      end

      def create_mailer
        return unless mails?

        template "app/mailers/rodauth_mailer.rb", "app/mailers/rodauth_mailer.rb"
        template "app/mailers/account_mailer.rb", "app/mailers/rodauth/#{account_path}_mailer.rb"
        directory "app/views/rodauth_mailer", "app/views/rodauth/#{account_path}_mailer"
      end

      private

      def only_json?
        ::Rails.application.config.api_only || !::Rails.application.config.session_store || options[:api_only]
      end

      def login_column
        options[:login_column] || "email"
      end
    end
  end
end

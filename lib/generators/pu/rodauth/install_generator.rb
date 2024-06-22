require "rails/generators/base"
require "rails/generators/active_record/migration"
require "securerandom"

module Pu
  module Rodauth
    class InstallGenerator < ::Rails::Generators::Base
      include ::ActiveRecord::Generators::Migration

      SEQUEL_ADAPTERS = {
        "postgresql" => (RUBY_ENGINE == "jruby") ? "postgresql" : "postgres",
        "mysql2" => (RUBY_ENGINE == "jruby") ? "mysql" : "mysql2",
        "sqlite3" => "sqlite",
        "oracle_enhanced" => "oracle",
        "sqlserver" => (RUBY_ENGINE == "jruby") ? "mssql" : "tinytds"
      }

      source_root "#{__dir__}/templates"

      desc "Install rodauth-rails"

      def add_rodauth
        Bundler.with_unbundled_env do
          run "bundle add bcrypt rodauth-rails"
        end
      end

      def create_rodauth_initializer
        template "config/initializers/rodauth.rb"
      end

      def create_rodauth_controller
        template "app/controllers/rodauth_controller.rb"
      end

      def create_rodauth_app
        template "app/rodauth/rodauth_app.rb"
        template "app/rodauth/rodauth_plugin.rb"
      end

      def add_dev_config
        insert_into_file "config/environments/development.rb",
          "\n  config.action_mailer.default_url_options = { host: '127.0.0.1', port: ENV.fetch('PORT', 3000) }\n",
          before: /^end/
      end

      def create_install_migration
        return unless activerecord_adapter == "postgresql"

        migration_template "db/migrate/install_rodauth.rb", "db/migrate/install_rodauth.rb" # , File.join(db_migrate_path, "#{migration_name}.rb")
      end

      def eject_layout
        file = "app/views/layouts/rodauth.html.erb"
        FileUtils.cp Plutonium.root.join(file), Rails.root.join(file)
      end

      def show_instructions
        readme "INSTRUCTIONS" if behavior == :invoke
      end

      private

      def sequel_adapter
        SEQUEL_ADAPTERS[activerecord_adapter] || activerecord_adapter
      end

      def activerecord_adapter
        if ActiveRecord::Base.respond_to?(:connection_db_config)
          ActiveRecord::Base.connection_db_config.adapter
        else
          ActiveRecord::Base.connection_config.fetch(:adapter)
        end
      end
    end
  end
end

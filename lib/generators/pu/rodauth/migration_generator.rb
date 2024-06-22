return unless defined?(Rodauth::Rails)

require "rails/generators/base"
require "rails/generators/active_record/migration"
require "erb"
require "digest"

require "#{__dir__}/concerns/configuration"
require "#{__dir__}/concerns/account_selector"

module Pu
  module Rodauth
    class MigrationGenerator < ::Rails::Generators::Base
      include ::ActiveRecord::Generators::Migration
      include Concerns::Configuration
      include Concerns::AccountSelector

      MIGRATION_DIR = "#{__dir__}/migration/active_record"

      source_root "#{__dir__}/templates"

      desc "Generate migrations for supported features\n\n" \
           "Supported Features\n" \
           "=========================================\n" \
           "#{MIGRATION_CONFIG.keys.sort.map(&:to_s).join "\n"}\n\n\n\n"

      class_option :features, required: true, type: :array,
        desc: "Rodauth features to create tables for (otp, sms_codes, single_session, account_expiration etc.)"

      def validate_selected_features
        if selected_features.empty?
          say "No migration features specified!", :yellow
          exit(1)
        elsif (selected_features - valid_features).any?
          say "No available migration for feature(s): #{(selected_features - valid_features).join(", ")}", :red
          exit(1)
        end
      end

      def create_rodauth_migration
        migration_template "db/migrate/create_rodauth.rb", File.join(db_migrate_path, "#{migration_name}.rb")
      end

      def configure_rodauth_plugin_tables
        in_root do
          break unless table_prefix != "account" && File.exist?(plugin_filename)

          gsub_file plugin_filename, /.*# accounts_table.*\n/, "" if selected_features.include? :base

          migration_overrides.sort.reverse_each do |key, value|
            override = indent "#{key} :#{value}\n", 4
            insert_into_file plugin_filename, override,
              after: /.*# Change prefix of table and.*\n/
          end
        end
      end

      def show_instructions
        in_root do
          break if table_prefix == "account" || File.exist?(plugin_filename)

          configuration = migration_overrides
            .map { |config, format| "#{config} :#{format}" }
            .join("\n")
            .indent(2)

          say "\n\nAdd the following to your Rodauth plugin configure block:", :blue
          say "\n\n#{configuration}\n\n\n\n", :magenta
        end
      end

      private

      def plugin_filename
        "app/rodauth/#{account_path}_rodauth_plugin.rb"
      end

      def migration_name
        @migration_name ||= begin
          max_len = 150
          migration_name = options[:migration_name] || ["create_rodauth", table_prefix, *selected_features].join("_")
          if migration_name.length <= max_len
            migration_name
          else
            [migration_name.first(max_len), Digest::SHA256.hexdigest(migration_name).first(10)].join("_")
          end
        end
      end

      def selected_features
        @selected_features ||= begin
          features = options[:features]
          features.unshift "base" if features.delete "base"
          features.map(&:to_sym)
        end
      end

      def migration_overrides
        @migration_overrides ||= migration_config.values_at(*selected_features)
          .flat_map(&:to_a)
          .map { |config, format| [config, (format % {plural: table_prefix.pluralize, singular: table_prefix})] }
          .to_h
          .compact
      end

      def migration_content
        selected_features
          .map { |feature| File.read(migration_chunk(feature)) }
          .map { |content| erb_eval(content) }
          .join("\n")
          .indent(4)
      end

      def erb_eval(content)
        ERB.new(content, trim_mode: "-").result(binding)
      end

      def separate_passwords?
        selected_features.include? :separate_passwords
      end

      def migration_chunk(feature)
        "#{MIGRATION_DIR}/#{feature}.erb"
      end

      def valid_features
        Dir["#{MIGRATION_DIR}/*.erb"].map { |filename| File.basename(filename, ".erb").to_sym }
      end

      def activerecord_adapter
        if ActiveRecord::Base.respond_to?(:connection_db_config)
          ActiveRecord::Base.connection_db_config.adapter
        else
          ActiveRecord::Base.connection_config.fetch(:adapter)
        end
      end

      def primary_key_type(key = :id)
        generators = ::Rails.application.config.generators
        column_type = generators.options[:active_record][:primary_key_type]
        if key
          ", #{key}: :#{column_type}" if column_type
        else
          column_type || default_primary_key_type
        end
      end

      def default_primary_key_type
        if ActiveRecord.version >= Gem::Version.new("5.1")
          :bigint
        else
          :integer
        end
      end

      # Active Record 7+ sets default precision to 6 for timestamp columns,
      # so we need to ensure we match this when setting the default value.
      def current_timestamp
        if ActiveRecord.version >= Gem::Version.new("7.0") && ["mysql2", "trilogy"].include?(activerecord_adapter) && ActiveRecord::Base.connection.supports_datetime_with_precision?
          "CURRENT_TIMESTAMP(6)"
        else
          "CURRENT_TIMESTAMP"
        end
      end
    end
  end
end

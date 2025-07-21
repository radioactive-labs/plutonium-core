# frozen_string_literal: true

require "rails/generators/named_base"
require_relative "../../lib/plutonium_generators"

module Pu
  module Res
    class EntityGenerator < ::Rails::Generators::NamedBase
      include PlutoniumGenerators::Generator

      desc "Generate an entity model for customer accounts"

      class_option :model, type: :boolean, default: true
      class_option :allow_signup, type: :boolean, default: true,
        desc: "Whether to allow customer to sign up to the platform"
      class_option :auth_account, type: :string,
        desc: "Specify the authentication account name", required: true

      def start
        generate_entity_resource
        generate_membership_resource
      end

      private

      def generate_entity_resource
        Rails::Generators.invoke(
          "pu:res:scaffold",
          [
            normalized_name,
            "name:string",
            "--model",
            ("--force" if options[:force]),
            ("--skip" if options[:skip]),
            "--dest=#{selected_destination_feature}"
          ].compact,
          behavior: behavior,
          destination_root: destination_root
        )

        add_unique_index_to_migration(normalized_name, [:name])
      end

      def generate_membership_resource
        Rails::Generators.invoke(
          "pu:res:scaffold",
          [
            normalized_entity_membership_name,
            *membership_attributes,
            "--model",
            ("--force" if options[:force]),
            ("--skip" if options[:skip]),
            "--dest=#{selected_destination_feature}"
          ].compact,
          behavior: behavior,
          destination_root: destination_root
        )

        add_unique_index_to_migration(
          normalized_entity_membership_name,
          ["#{normalized_name}_id", "#{normalized_auth_account_name}_id"]
        )
      end

      private

      def selected_destination_feature = "main_app"

      def normalized_name = name.underscore

      def normalized_entity_membership_name
        "#{normalized_name}_#{normalized_auth_account_name}"
      end

      def normalized_auth_account_name = options[:auth_account].underscore

      def add_unique_index_to_migration(model_name, index_columns)
        migration_dir = File.join("db", "migrate")
        migration_file = Dir[File.join(migration_dir, "*_create_#{model_name.pluralize}.rb")].first

        if migration_file && File.exist?(migration_file)
          index_definition = build_index_definition(model_name, index_columns)
          insert_into_file migration_file, indent(index_definition, 4), before: /^  end\s*$/
          success "Added unique index to #{model_name.pluralize}"
        end
      end

      def build_index_definition(model_name, index_columns)
        table_name = model_name.pluralize

        case index_columns
        when Array
          if index_columns.size == 1
            "add_index :#{table_name}, :#{index_columns.first}, unique: true\n"
          else
            column_list = index_columns.map { |col| ":#{col}" }.join(", ")
            "add_index :#{table_name}, [#{column_list}], unique: true\n"
          end
        else
          "add_index :#{table_name}, :#{index_columns}, unique: true\n"
        end
      end

      def membership_attributes
        [
          "#{normalized_name}:references",
          "#{normalized_auth_account_name}:references",
          "role:integer"
        ]
      end
    end
  end
end

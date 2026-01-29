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
        ensure_customer_model_exists! if behavior == :invoke
        generate_entity_resource
        generate_membership_resource
      end

      private

      def ensure_customer_model_exists!
        customer_model_path = File.join("app", "models", "#{normalized_auth_account_name}.rb")
        unless File.exist?(customer_model_path)
          raise "Customer model '#{normalized_auth_account_name}' does not exist. Please create it first."
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      def generate_entity_resource
        # Use class-based invocation to avoid Thor's invoke caching
        klass = Rails::Generators.find_by_namespace("pu:res:scaffold")
        klass.new(
          [normalized_name, "name:string"],
          {
            dest: selected_destination_feature,
            model: true,
            force: options[:force],
            skip: options[:skip]
          }
        ).invoke_all

        add_unique_index_to_migration(normalized_name, [:name])
      end

      def generate_membership_resource
        # Use class-based invocation to avoid Thor's invoke caching
        klass = Rails::Generators.find_by_namespace("pu:res:scaffold")
        klass.new(
          [normalized_entity_membership_name, *membership_attributes],
          {
            dest: selected_destination_feature,
            model: true,
            force: options[:force],
            skip: options[:skip]
          }
        ).invoke_all

        add_unique_index_to_migration(
          normalized_entity_membership_name,
          ["#{normalized_name}_id", "#{normalized_auth_account_name}_id"]
        )

        add_default_to_role_column
        add_role_enum_to_model
        add_unique_validation_to_model
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

        modify_file_if_exists(migration_file) do |file|
          index_definition = build_index_definition(model_name, index_columns)
          insert_into_file migration_file, indent(index_definition, 4), before: /^  end\s*$/
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

      def add_default_to_role_column
        migration_dir = File.join("db", "migrate")
        migration_file = Dir[File.join(migration_dir, "*_create_#{normalized_entity_membership_name.pluralize}.rb")].first

        modify_file_if_exists(migration_file) do |file|
          gsub_file file, /t\.integer :role, null: false/, "t.integer :role, null: false, default: 0  # Member by default"
        end
      end

      def add_role_enum_to_model
        model_file = File.join("app", "models", "#{normalized_entity_membership_name}.rb")

        modify_file_if_exists(model_file) do |file|
          enum_definition = "\nenum :role, member: 0, owner: 1"
          insert_into_file file, indent(enum_definition, 2), before: /^\s*# add model configurations above\./
        end
      end

      def add_unique_validation_to_model
        model_file = File.join("app", "models", "#{normalized_entity_membership_name}.rb")

        modify_file_if_exists(model_file) do |file|
          validation_definition = "validates :#{normalized_auth_account_name}, uniqueness: {scope: :#{normalized_name}_id, message: \"is already a member of this entity\"}\n"
          insert_into_file file, indent(validation_definition, 2), before: /^\s*# add validations above\./
        end
      end

      def modify_file_if_exists(file_path)
        return unless file_path && File.exist?(file_path)
        yield(file_path)
      end
    end
  end
end

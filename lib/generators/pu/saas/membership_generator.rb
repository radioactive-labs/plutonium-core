# frozen_string_literal: true

require "rails/generators/base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class MembershipGenerator < ::Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Generate a SaaS membership model linking users to entities"

      class_option :user, type: :string, required: true,
        desc: "The user model name (e.g., Customer)"

      class_option :entity, type: :string, required: true,
        desc: "The entity model name (e.g., Organization)"

      class_option :roles, type: :array, default: %w[member owner],
        desc: "Available roles for memberships"

      class_option :extra_attributes, type: :array, default: [],
        desc: "Additional attributes for the membership model"

      def start
        validate_models_exist!
        generate_membership_model
        add_unique_index_to_migration
        add_default_to_role_column
        add_role_enum_to_model
        add_unique_validation_to_model
        add_associations_to_models
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def validate_models_exist!
        user_model_path = File.join("app", "models", "#{normalized_user_name}.rb")
        entity_model_path = File.join("app", "models", "#{normalized_entity_name}.rb")

        unless File.exist?(user_model_path)
          raise "User model '#{normalized_user_name}' does not exist at #{user_model_path}. Please create it first with: rails g pu:saas:user #{options[:user]}"
        end

        unless File.exist?(entity_model_path)
          raise "Entity model '#{normalized_entity_name}' does not exist at #{entity_model_path}. Please create it first with: rails g pu:saas:entity #{options[:entity]}"
        end
      end

      def generate_membership_model
        invoke "pu:res:model", [membership_model_name, *membership_attributes],
          dest: selected_destination_feature,
          force: options[:force],
          skip: options[:skip]
      end

      def add_unique_index_to_migration
        migration_file = find_migration_file

        return unless migration_file

        insert_into_file migration_file,
          indent("add_index :#{membership_table_name}, [:#{normalized_entity_name}_id, :#{normalized_user_name}_id], unique: true\n", 4),
          before: /^  end\s*$/
      end

      def add_default_to_role_column
        migration_file = find_migration_file

        return unless migration_file

        gsub_file migration_file,
          /t\.integer :role, null: false/,
          "t.integer :role, null: false, default: 0"
      end

      def add_role_enum_to_model
        model_file = File.join("app", "models", "#{membership_model_name}.rb")

        return unless File.exist?(model_file)

        enum_definition = "enum :role, #{roles_enum}\n"
        insert_into_file model_file, indent(enum_definition, 2), before: /^\s*# add enums above\./
      end

      def add_unique_validation_to_model
        model_file = File.join("app", "models", "#{membership_model_name}.rb")

        return unless File.exist?(model_file)

        validation = "validates :#{normalized_user_name}, uniqueness: {scope: :#{normalized_entity_name}_id, message: \"is already a member of this #{normalized_entity_name.humanize.downcase}\"}\n"
        insert_into_file model_file, indent(validation, 2), before: /^\s*# add validations above\./
      end

      def add_associations_to_models
        add_association_to_entity_model
        add_association_to_user_model
      end

      def add_association_to_entity_model
        entity_model_path = File.join("app", "models", "#{normalized_entity_name}.rb")

        return unless File.exist?(entity_model_path)

        associations = <<~RUBY
          has_many :#{membership_table_name}, dependent: :destroy
          has_many :#{normalized_user_name.pluralize}, through: :#{membership_table_name}
        RUBY
        inject_into_file entity_model_path, associations, before: /^\s*# add has_many associations above\.\n/
      end

      def add_association_to_user_model
        user_model_path = File.join("app", "models", "#{normalized_user_name}.rb")

        return unless File.exist?(user_model_path)

        associations = <<~RUBY
          has_many :#{membership_table_name}, dependent: :destroy
          has_many :#{normalized_entity_name.pluralize}, through: :#{membership_table_name}
        RUBY
        inject_into_file user_model_path, associations, before: /^\s*# add has_many associations above\.\n/
      end

      def find_migration_file
        migration_dir = File.join("db", "migrate")
        Dir[File.join(migration_dir, "*_create_#{membership_table_name}.rb")].first
      end

      def membership_model_name
        "#{normalized_entity_name}_#{normalized_user_name}"
      end

      def membership_table_name
        membership_model_name.pluralize
      end

      def membership_attributes
        [
          "#{normalized_entity_name}:references",
          "#{normalized_user_name}:references",
          "role:integer",
          *Array(options[:extra_attributes])
        ]
      end

      def normalized_user_name = options[:user].underscore

      def normalized_entity_name = options[:entity].underscore

      def roles
        Array(options[:roles]).flat_map { |r| r.split(",") }.map(&:strip)
      end

      def roles_enum
        roles.each_with_index.map { |r, i| "#{r}: #{i}" }.join(", ")
      end

      def selected_destination_feature
        feature_option :dest, prompt: "Select destination feature"
      end
    end
  end
end

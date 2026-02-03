# frozen_string_literal: true

require "rails/generators/named_base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class EntityGenerator < ::Rails::Generators::NamedBase
      include PlutoniumGenerators::Generator

      desc "Generate a SaaS entity model (organization/tenant)"

      class_option :extra_attributes, type: :array, default: [],
        desc: "Additional attributes for the entity model"

      def start
        generate_entity_resource
        add_unique_index_to_migration
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def generate_entity_resource
        invoke "pu:res:scaffold", [normalized_name, *entity_attributes],
          dest: selected_destination_feature,
          model: true,
          force: options[:force],
          skip: options[:skip]
      end

      def add_unique_index_to_migration
        migration_dir = File.join("db", "migrate")
        migration_file = Dir[File.join(migration_dir, "*_create_#{normalized_name.pluralize}.rb")].first

        return unless migration_file && File.exist?(migration_file)

        insert_into_file migration_file,
          indent("add_index :#{normalized_name.pluralize}, :name, unique: true\n", 4),
          before: /^  end\s*$/
      end

      def entity_attributes
        ["name:string", *Array(options[:extra_attributes])]
      end

      def normalized_name = name.underscore

      def selected_destination_feature
        feature_option :dest, prompt: "Select destination feature"
      end
    end
  end
end

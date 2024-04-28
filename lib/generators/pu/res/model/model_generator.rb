# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Res
    class ModelGenerator < PlutoniumGenerators::ModelGenerator
      source_root File.expand_path("templates", __dir__)

      def run_create_module
        create_module_file if @create_files
      end

      def run_create_model
        model_class = class_name.safe_constantize
        if model_class.present? && !model_class.include?(Plutonium::Resource::Record)
          insert_into_file File.join("app/models", class_path, "#{file_name}.rb"),
            indent("include Plutonium::Resource::Record\n", 2),
            after: /.*class .*\n/
        end

        create_model_file if @create_files
      end

      def run_create_migration
        create_migration_file if @create_files
      end

      private

      def create_files?
        attributes.present?
      end
    end
  end
end

# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Res
    class ModelGenerator < PlutoniumGenerators::ModelGeneratorBase
      source_root File.expand_path("templates", __dir__)

      def run_create_module
        create_module_file if create_files?
      end

      def run_create_model
        create_model_file if create_files?
      end

      def run_create_migration
        create_migration_file if create_files?
      end

      private

      def create_files?
        attributes.present?
      end
    end
  end
end

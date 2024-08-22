# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Res
    class ScaffoldGenerator < PlutoniumGenerators::ModelGeneratorBase
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Scaffold a resource"

      class_option :model, type: :boolean, default: true

      def setup
        return unless options[:model]

        model_class = class_name.safe_constantize
        if model_class.present? && attributes.empty? && prompt.yes?("Existing model class found. Do you want to import its attributes?")
          attributes_str = model_class.content_columns.map { |col| "#{col.name}:#{col.type}" }
          self.attributes = parse_attributes_internal!(attributes_str)
        end
      end

      def create_model
        return unless options[:model]

        invoke "pu:res:model", [@original_name, *@original_attributes], dest: selected_destination_feature, **options
      end

      def create_controller
        template "controller.rb", File.join("app/controllers", class_path, "#{file_name.pluralize}_controller.rb")
      end

      def create_policy
        template "policy.rb", File.join("app/policies", class_path, "#{file_name}_policy.rb")
      end

      def create_definition
        template "definition.rb", File.join("app/definitions", class_path, "#{file_name}_definition.rb")
      end

      # def create_presenter
      #   template "presenter.rb", File.join("app/presenters", class_path, "#{file_name}_presenter.rb")
      # end

      # def create_query_object
      #   template "query_object.rb", File.join("app/query_objects", class_path, "#{file_name}_query_object.rb")
      # end

      private

      def default_policy_attributes
        attributes.select { |a| !a.rich_text? && !a.password_digest? && !a.token? }.map(&:attribute_name).map(&:to_sym)
      end

      def policy_attributes_for_create
        default_policy_attributes
      end

      def policy_attributes_for_read
        default_policy_attributes + [:created_at, :updated_at]
      end
    end
  end
end

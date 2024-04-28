# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Res
    class ScaffoldGenerator < PlutoniumGenerators::ModelGenerator
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Scaffold a resource"

      class_option :package, type: :string

      def setup
        model_class = class_name.safe_constantize
        if model_class.present? && attributes.empty? && prompt.yes?("Existing model class found. Do you want to import its attributes?")
          attributes_str = model_class.content_columns.map { |col| "#{col.name}:#{col.type}" }
          self.attributes = parse_attributes_internal!(attributes_str)
        end
      end

      def create_model
        invoke "pu:res:model", [name, *@original_attributes], **options
      end

      def create_controller
        template "controller.rb", File.join("app/controllers", class_path, "#{file_name.pluralize}_controller.rb")
      end

      def create_policy
        template "policy.rb", File.join("app/policies", class_path, "#{file_name}_policy.rb")
      end

      def create_presenter
        template "presenter.rb", File.join("app/presenters", class_path, "#{file_name}_presenter.rb")
      end

      def create_query_object
        template "query_object.rb", File.join("app/query_objects", class_path, "#{file_name}_query_object.rb")
      end

      # SSSSS

      def name
        @pu_name ||= begin
          @selected_feature = select_feature selected_feature
          @name = [main_app? ? nil : selected_feature.underscore, super.singularize.underscore].compact.join "/"
          set_destination_root!
          @name
        end
      end

      def feature_package_name
        main_app? ? nil : selected_feature.camelize
      end

      def main_app?
        selected_feature == "main_app"
      end

      def selected_feature
        @selected_feature || options[:feature]
      end

      def set_destination_root!
        @destination_stack = [File.join(Rails.root, main_app? ? "" : "packages/#{selected_feature.underscore}")]
      end
    end
  end
end

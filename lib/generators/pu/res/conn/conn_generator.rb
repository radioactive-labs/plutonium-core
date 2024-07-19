# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Res
    class ConnGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Create a connection between a resource and an app"

      # argument :name

      def start
        source_feature = select_feature msg: "Select source feature"
        source_module = (source_feature == "main_app") ? "ResourceRecord" : "#{source_feature.camelize}::ResourceRecord"

        Plutonium.eager_load_rails!
        available_resources = source_module.constantize.descendants.map(&:to_s).sort
        error "No resources found" if available_resources.blank?
        selected_resources = prompt.multi_select("Select resources", available_resources)

        @app_namespace = select_app.camelize

        selected_resources.each do |resource|
          @resource_class = resource

          template "app/controllers/resource_controller.rb", "packages/#{package_namespace}/app/controllers/#{package_namespace}/#{resource.pluralize.underscore}_controller.rb"
          template "app/policies/resource_policy.rb", "packages/#{package_namespace}/app/policies/#{package_namespace}/#{resource.underscore}_policy.rb" unless expected_parent_policy
          template "app/presenters/resource_presenter.rb", "packages/#{package_namespace}/app/presenters/#{package_namespace}/#{resource.underscore}_presenter.rb" unless expected_parent_presenter
          template "app/query_objects/resource_query_object.rb", "packages/#{package_namespace}/app/query_objects/#{package_namespace}/#{resource.underscore}_query_object.rb" unless expected_parent_query_object

          insert_into_file "packages/#{package_namespace}/config/routes.rb",
            indent("register_resource ::#{resource}\n", 2),
            before: /.*# register resources above.*/
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      attr_reader :app_namespace, :resource_class

      def package_namespace
        app_namespace.underscore
      end

      def resource_namespace
        app_namespace.underscore
      end

      def expected_parent_controller
        expected_parent_controller = "::#{resource_class.pluralize}Controller".safe_constantize
        expected_parent_controller if expected_parent_controller.present? && expected_parent_controller < ::ResourceController
      end

      def parent_controller
        expected_parent_controller || "#{app_namespace}::ResourceController"
      end

      def expected_parent_policy
        expected_parent_policy = "::#{resource_class.pluralize}Policy".safe_constantize
        expected_parent_policy if expected_parent_policy.present? && expected_parent_policy < ::ResourcePolicy
      end

      def parent_policy
        expected_parent_policy || "ResourcePolicy"
      end

      def expected_parent_presenter
        expected_parent_presenter = "::#{resource_class.pluralize}Presenter".safe_constantize
        expected_parent_presenter if expected_parent_presenter.present? && expected_parent_presenter < ::ResourcePresenter
      end

      def parent_presenter
        expected_parent_presenter || "ResourcePresenter"
      end

      def expected_parent_query_object
        expected_parent_query_object = "::#{resource_class.pluralize}QueryObject".safe_constantize
        expected_parent_query_object if expected_parent_query_object.present? && expected_parent_query_object < ::ResourceQueryObject
      end

      def parent_query_object
        expected_parent_query_object || "ResourceQueryObject"
      end

      def attributes
        resource_klass = resource_class.constantize
        unwanted_attrs = [
          resource_klass.primary_key.to_sym, # primary_key
          :created_at, :updated_at # timestamps
        ]
        resource_klass.content_columns.filter_map { |col|
          next if unwanted_attrs.include? col.name.to_sym

          PlutoniumGenerators::ModelGeneratorBase::GeneratedAttribute.parse resource_class, "#{col.name}:#{col.type}"
        }
      end
    end
  end
end

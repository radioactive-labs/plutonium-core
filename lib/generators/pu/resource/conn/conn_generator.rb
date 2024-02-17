# frozen_string_literal: true

require "plutonium_generators"

module Pu
  module Resource
    class ConnGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Create a connection between a resource and an app"

      # argument :name

      def start
        source_feature = select_feature
        source_module = (source_feature == "main_app") ? "ResourceRecord" : "#{source_feature.classify}::ResourceRecord"

        Rails.application.eager_load!
        available_resources = source_module.constantize.descendants.map(&:to_s)
        selected_resources = prompt.multi_select("Select resources", available_resources)

        @app_namespace = select_app.classify

        selected_resources.each do |resource|
          @resource_class = resource

          template "app/controllers/resource_controller.rb", "packages/#{package_namespace}/app/controllers/#{package_namespace}/#{resource.pluralize.underscore}_controller.rb"
          template "app/policies/resource_policy.rb", "packages/#{package_namespace}/app/policies/#{package_namespace}/#{resource.underscore}_policy.rb"
          template "app/presenters/resource_presenter.rb", "packages/#{package_namespace}/app/presenters/#{package_namespace}/#{resource.underscore}_presenter.rb"

          insert_into_file "packages/#{package_namespace}/lib/engine.rb",
            indent("register_resource ::#{resource}\n", 6),
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
    end
  end
end

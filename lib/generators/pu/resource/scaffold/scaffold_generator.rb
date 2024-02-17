# frozen_string_literal: true

require "plutonium_generators"

module Pu
  module Resource
    class ScaffoldGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Scaffold a resource"

      argument :name
      class_option :env, type: :string, default: "all"

      def start
        setup_models
        scaffold_route
        scaffold_controllers
        scaffold_views
        scaffold_policies
        scaffold_presenters
      rescue => e
        exception "Resource scaffold failed:", e
      end

      protected

      def setup_models
        return if resource_class < Pu::ResourceModel

        insert_into_file "app/models/#{resource_path}.rb",
          indent("include ResourceModel\n", 2),
          before: /.*# pu:add concerns.*\n/
      end

      def scaffold_route
        route_exists = File.read("config/routes.rb").match?(/concern :#{resource_name_underscored}_routes do/)
        return if route_exists && skip_existing?

        if resource_module_underscored.present?
          indentation = "  resources :#{resource_name_plural_underscored}, ".size
          module_config = [
            "module: '#{resource_module_underscored}'",
            "controller: '#{resource_attribute_plural}'",
            "path: '#{resources_path}'"
          ].map { |c| indent c, indentation }.join(",\n")
          module_config = ",\n#{module_config}"
        end
        route = <<~TILDE
          concern :#{resource_name_underscored}_routes do
            #{resource_name_underscored}_concerns = %i[]
            #{resource_name_underscored}_concerns += shared_resource_concerns
            resources :#{resource_name_plural_underscored}, concerns: #{resource_name_underscored}_concerns#{module_config} do
              # pu:routes:#{resource_name_plural_underscored}
            end
          end
          entity_resource_routes << :#{resource_name_underscored}_routes
          admin_resource_routes << :#{resource_name_underscored}_routes
        TILDE

        route.gsub!(/entity_resource_routes << :#{resource_name_underscored}_routes\n/, "") if admin_only?
        route = indent route, 2

        if route_exists
          gsub_file "config/routes.rb",
            /.*concern :#{resource_name_underscored}_routes do(.|\n)*<< :#{resource_name_underscored}_routes\n/,
            route
        else
          insert_into_file "config/routes.rb",
            "#{route}\n",
            before: /.*# pu:add #{entity? ? "entity" : "resource"} routes above.*/
        end
      end

      def scaffold_controllers
        template "app/controllers/admin_resources/resource_controller.rb",
          "app/controllers/admin_resources/#{resources_path}_controller.rb", skip: skip_existing?

        return if admin_only?

        template "app/controllers/entity_resources/resource_controller.rb",
          "app/controllers/entity_resources/#{resources_path}_controller.rb", skip: skip_existing?
      end

      def scaffold_views
        %w[entity_resources admin_resources].each do |subdir|
          next if subdir != "admin_resources" && admin_only?

          create_file "app/views/#{subdir}/#{resources_path}/.keep", ""

          #   template 'app/views/resources/resource/_resource.html.erb',
          #            "app/views/#{subdir}/#{resources_path}/_#{resource_attribute}.html.erb", skip: skip_existing?
          #   copy_file 'app/views/resources/resource/_resource.rabl',
          #             "app/views/#{subdir}/#{resources_path}/_#{resource_attribute}.rabl", skip: skip_existing?
        end
      end

      def scaffold_policies
        template "app/policies/resources/resource_policy.rb",
          "app/policies/resources/#{resource_path}_policy.rb", skip: skip_existing?

        template "app/policies/resources/admin/resource_policy.rb",
          "app/policies/resources/admin/#{resource_path}_policy.rb", skip: skip_existing?

        return if admin_only?

        template "app/policies/resources/entity/resource_policy.rb",
          "app/policies/resources/entity/#{resource_path}_policy.rb", skip: skip_existing?
      end

      def scaffold_presenters
        template "app/resources/resource/presenter.rb",
          "app/resources/#{resources_path}/presenter.rb", skip: skip_existing?
        template "app/resources/resource/admin_presenter.rb",
          "app/resources/#{resources_path}/admin_presenter.rb", skip: skip_existing?

        return if admin_only?

        template "app/resources/resource/entity_presenter.rb",
          "app/resources/#{resources_path}/entity_presenter.rb", skip: skip_existing?
      end

      def create_fields
        @create_fields ||= (resource_class.attribute_names - %w[id slug created_at updated_at]).map(&:to_sym)
      end

      def read_fields
        @read_fields ||= begin
          attribute_names = resource_class.attribute_names.reject { |attr| associations[attr] }
          attribute_names = attribute_names.map(&:to_sym)
          attribute_names.insert(1, entity_assoc.name) if entity_assoc
          attribute_names - %i[]
        end
      end

      def associations
        @associations ||= resource_class.reflect_on_all_associations.map do |assoc|
          [assoc.foreign_key, assoc]
        end.compact.to_h.with_indifferent_access
      end

      def entity_assoc(source_class = nil)
        @entity_assoc ||= {}

        source_class ||= resource_class
        @entity_assoc[source_class] ||= begin
          matcher = lambda do |assoc|
            assoc_class = assoc.class_name.constantize
            assoc_class == Entity || assoc_class < Entity
          rescue
            false
          end

          assoc = source_class.reflect_on_all_associations(:belongs_to).select(&matcher).first
          assoc ||= source_class.reflect_on_all_associations(:has_one).select(&matcher).first
          assoc
        end
      end

      def assoc?(attr)
        resource_class.reflect_on_association(attr)
      end

      def admin_only?
        entity? || entity_assoc.nil?
      end

      def entity?
        resource_class == Entity || resource_class < Entity
      end

      def resource_name
        @resource_name ||= name.classify
      end

      def resource_name_plural
        @resource_name_plural ||= resource_name.pluralize
      end

      def resource_class
        @resource_class ||= resource_name.constantize
      end

      def resource_name_underscored
        @resource_name_underscored ||= resource_name.underscore.tr("/", "_")
      end

      def resource_name_plural_underscored
        @resource_name_plural_underscored ||= resource_name_plural.underscore.tr("/", "_")
      end

      def resource_path
        @resource_path ||= resource_name.underscore
      end

      def resources_path
        @resources_path ||= resource_name_plural.underscore
      end

      def resource_attribute
        @resource_attribute ||= resource_name.demodulize.underscore
      end

      def resource_attribute_plural
        @resource_attribute_plural ||= resource_name_plural.demodulize.underscore
      end

      def resource_module_underscored
        @resource_module_underscored ||= resource_name.deconstantize.underscore
      end

      def skip_existing?
        !options[:force]
      end
    end
  end
end

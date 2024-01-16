require "rails/engine"

module Plutonium
  module App
    extend ActiveSupport::Concern
    include Package

    included do
      isolate_namespace to_s.deconstantize.constantize
    end

    class_methods do
      def register_resource(resource)
        @resource_register ||= []
        @resource_register << resource
      end

      def resource_register
        @resource_register || []
      end

      def draw_resource_routes
        # We want our resources sorted in reverse order in order to prevent routing conflicts
        # e.g. /blogs/1 and blogs/comments cause an issue if Blog is registered before Blogs::Comment
        # attempting to load blogs/comments routes to blogs/:id which fails with a 404
        # Reverse sorting ensures that nested resources are registered first
        registered_resources = resource_register.sort.reverse

        routes.draw do
          registered_resources.each do |resource|
            resource_name = resource.to_s.classify

            resource_module = resource_name.deconstantize
            resource_module_underscored = resource_module&.underscore

            resource_name_plural = resource_name.pluralize
            resource_name_plural_underscored = resource_name_plural.underscore.tr("/", "_")
            resource_controller = resource_name_plural.demodulize.underscore

            resources_path = resource_name_plural.underscore

            route_opts = {}
            if resource_module_underscored.present?
              route_opts[:module] = resource_module_underscored
              route_opts[:controller] = resource_controller
              route_opts[:path] = resources_path
            end
            # route = <<~TILDE
            #   concern :#{resource_name_underscored}_routes do
            #     #{resource_name_underscored}_concerns = %i[]
            #     #{resource_name_underscored}_concerns += shared_resource_concerns
            #     resources :#{resource_name_plural_underscored}, concerns: #{resource_name_underscored}_concerns#{module_config} do
            #       # pu:routes:#{resource_name_plural_underscored}
            #     end
            #   end
            #   entity_resource_routes << :#{resource_name_underscored}_routes
            #   admin_resource_routes << :#{resource_name_underscored}_routes
            # TILDE

            resources resource_name_plural_underscored, **route_opts
          end
        end
      end
    end
  end
end

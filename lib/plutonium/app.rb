require "rails/engine"

module Plutonium
  module App
    extend ActiveSupport::Concern

    included do
      # include Package
      isolate_namespace to_s.deconstantize.constantize

      # prevent this package from being added to the view lookup
      config.before_configuration do
        # this touches the internals of rails, but I could not find a good way of doing this
        # we get the initializer instance and set the block property to a noop
        add_view_paths_initializer = Rails.application.initializers.find do |a|
          a.context_class == self && a.name.to_s == "add_view_paths"
        end
        add_view_paths_initializer.instance_variable_set(:@block, ->(app) {})
      end
    end

    module ClassMethods
      def register_resource(resource)
        @resource_register ||= []
        @resource_register << resource
      end

      def resource_register
        @resource_register || []
      end

      def draw_resource_routes
        registered_resources = resource_register
        routes.draw do
          registered_resources.each do |resource|
            resource_name = resource.to_s.classify

            resource_module = resource_name.deconstantize
            resource_module_underscored = resource_module&.underscore

            resource_name_plural = resource_name.pluralize
            resource_name_plural_underscored = resource_name_plural.underscore.tr("/", "_")
            resource_attribute_plural = resource_name_plural.demodulize.underscore

            resources_path = resource_name_plural.underscore

            route_opts = {}
            if resource_module_underscored.present?
              route_opts[:module] = resource_module_underscored
              route_opts[:controller] = resource_attribute_plural
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

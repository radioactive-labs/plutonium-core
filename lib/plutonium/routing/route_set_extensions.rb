# frozen_string_literal: true

module Plutonium
  module Routing
    # RouteSetExtensions module provides additional functionality for route management in Plutonium applications.
    #
    # This module extends the functionality of Rails' routing system to support Plutonium-specific features,
    # such as resource registration and custom route drawing.
    #
    # @example Usage in a Rails application
    #   Blorgh::Engine.routes.draw do
    #     register_resource SomeModel
    #   end
    module RouteSetExtensions
      extend ActiveSupport::Concern
      include Plutonium::Engine::Validator

      # Clears all registered resources and route configurations.
      #
      # This method should be called when you want to reset all registered resources
      # and start with a clean slate for route definition.
      #
      # @return [void]
      def clear!
        resource_route_config_lookup.clear
        engine.resource_register.clear
        super
      end

      # Draws routes with additional Plutonium-specific setup and resource materialization.
      #
      # @param block [Proc] The block containing route definitions.
      # @return [void]
      # @yield Executes the given block in the context of route drawing.
      def draw(&block)
        if self.class.supported_engine?(engine)
          ActiveSupport::Notifications.instrument("plutonium.resource_routes.draw", app: engine.to_s) do
            super do
              setup_shared_resource_concerns
              instance_exec(&block)
              materialize_resource_routes
            end
          end
        else
          super
        end
      end

      # Registers a resource for routing.
      #
      # @param resource [Class] The resource class to be registered.
      # @param options [Hash] Additional options for resource registration.
      # @yield An optional block for additional resource configuration.
      # @return [Hash] The configuration for the registered resource.
      # @raise [ArgumentError] If the engine is not supported.
      def register_resource(resource, options = {}, &)
        self.class.validate_engine! engine
        engine.resource_register.register(resource)

        route_name = resource.model_name.plural
        concern_name = :"#{route_name}_routes"

        config = create_resource_config(resource, route_name, concern_name, options, &)
        resource_route_config_lookup[route_name] = config

        config
      end

      # Retrieves the route configuration for specified routes.
      #
      # @param routes [Array<Symbol>] The route names to fetch configurations for.
      # @return [Array<Hash>] An array of route configurations.
      def resource_route_config_for(*routes)
        routes = Array(routes)
        resource_route_config_lookup.slice(*routes).values
      end

      # Returns the current engine for the routes.
      #
      # @return [Class] The engine class (Rails application or custom engine).
      def engine
        @engine ||= determine_engine
      end

      # @return [Hash] A lookup table for resource route configurations.
      # Keys are either plural names (e.g., "profiles") for top-level routes
      # or "parent_plural/child_plural" (e.g., "users/profiles") for nested routes.
      def resource_route_config_lookup
        @resource_route_config_lookup ||= {}
      end

      private

      # Determines the appropriate engine based on the current scope.
      #
      # @return [Class] The determined engine class.
      def determine_engine
        engine_module = default_scope&.fetch(:module)
        engine_module.present? ? "#{engine_module.camelize}::Engine".constantize : Rails.application.class
      end

      # Creates a resource configuration hash.
      #
      # @param resource_name [String] The name of the resource.
      # @param route_name [String] The pluralized name for routes.
      # @param concern_name [Symbol] The name of the concern for this resource.
      # @param options [Hash] Additional options for resource registration.
      # @yield An optional block for additional resource configuration.
      # @return [Hash] The complete resource configuration.
      def create_resource_config(resource, route_name, concern_name, options = {}, &block)
        {
          route_type: options[:singular] ? :resource : :resources,
          route_name: route_name,
          concern_name: concern_name,
          route_options: {
            controller: resource.to_s.pluralize.underscore,
            path: options[:singular] ? resource.model_name.singular : resource.model_name.collection,
            concerns: %i[interactive_resource_actions]
          },
          block: block
        }
      end
    end
  end
end

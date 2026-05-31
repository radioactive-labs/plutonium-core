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
        if engine
          resource_route_config_lookup.clear
          engine.resource_register.clear
        end

        super
      end

      # Draws routes with additional Plutonium-specific setup and resource materialization.
      #
      # @param block [Proc] The block containing route definitions.
      # @return [void]
      # @yield Executes the given block in the context of route drawing.
      def draw(&block)
        if self.class.supported_engine?(engine)
          scope_params = entity_scope_params_for_path_strategy
          ActiveSupport::Notifications.instrument("plutonium.resource_routes.draw", app: engine.to_s) do
            super do
              setup_shared_resource_concerns
              draw_routes_with_entity_scope(scope_params, &block)
            end
          end
        else
          super
        end
      end

      # Determines entity scope parameters for path-based scoping.
      #
      # @return [Hash, nil] Scope params if path-based scoping is enabled, nil otherwise
      def entity_scope_params_for_path_strategy
        return nil unless engine.scoped_entity_strategy == :path

        param_key = engine.scoped_entity_param_key
        {
          name: ":#{param_key}",
          options: {as: param_key}
        }
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

      # Checks if a resource is registered as a singular route.
      #
      # @param route_key [String] The route key (e.g., "users" or "users/profiles")
      # @return [Boolean] true if the resource is a singular route, false otherwise
      def singular_resource_route?(route_key)
        resource_route_config_for(route_key)[0]&.[](:route_type) == :resource
      end

      # Returns the current engine for the routes.
      #
      # Memoizes via defined? so a nil result (non-Plutonium route set) is cached
      # instead of being recomputed on every call.
      #
      # @return [Class, nil] The owning engine, or nil if not a Plutonium engine.
      def engine
        return @engine if defined?(@engine)

        @engine = determine_engine
      end

      # @return [Hash] A lookup table for resource route configurations.
      # Keys are either plural names (e.g., "profiles") for top-level routes
      # or "parent_plural/child_plural" (e.g., "users/profiles") for nested routes.
      def resource_route_config_lookup
        @resource_route_config_lookup ||= {}
      end

      private

      # Determines the Plutonium engine that owns this route set, if any.
      #
      # Plutonium engines follow the SomeModule::Engine convention. A route set
      # with no module scope belongs to the application. Anything else (e.g.
      # graphql-ruby's Graphql::Dashboard, whose engine class is the module
      # itself with no nested ::Engine) is not a Plutonium engine and has nothing
      # for us to manage, so we return nil and let #clear!/#draw skip it rather
      # than raise during route reload.
      #
      # @return [Class, nil] The owning engine, or nil if not a Plutonium engine.
      def determine_engine
        engine_module = default_scope&.fetch(:module)
        return Rails.application.class if engine_module.blank?

        "#{engine_module.camelize}::Engine".safe_constantize
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
          resource_class: resource,
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

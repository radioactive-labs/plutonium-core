# frozen_string_literal: true

module Plutonium
  module Routing
    # MapperExtensions module provides additional functionality for route mapping in Plutonium applications.
    #
    # This module extends the functionality of Rails' routing mapper to support Plutonium-specific features,
    # such as resource registration and custom route materialization.
    #
    # @example Usage in a Rails routes file
    #   Blorgh::Engine.routes.draw do
    #     register_resource SomeModel
    #   end
    module MapperExtensions
      # Registers a resource for routing and sets up associated routes.
      #
      # @param resource [Class] The resource class to be registered.
      # @param options [Hash] Additional options for resource registration.
      # @yield An optional block for additional resource configuration.
      # @return [void]
      def register_resource(resource, options = {}, &)
        route_config = route_set.register_resource(resource, &)
        define_resource_routes(route_config, resource)
        resource_route_concern_names << route_config[:concern_name]
      end

      private

      # @return [Array<Symbol>] Names of resource route concerns.
      def resource_route_concern_names
        @resource_route_concern_names ||= []
      end

      # Sets up shared concerns for interactive resource actions.
      #
      # @return [void]
      def setup_shared_resource_concerns
        concern :interactive_resource_actions do
          define_member_interactive_actions
          define_collection_interactive_actions
        end
      end

      # Materializes all registered resource routes.
      #
      # @return [void]
      def materialize_resource_routes
        engine = route_set.engine
        scope_params = determine_scope_params(engine)

        scope scope_params[:name], scope_params[:options] do
          concerns resource_route_concern_names.sort
        end
      end

      # @return [ActionDispatch::Routing::RouteSet] The current route set.
      def route_set
        @set
      end

      # Defines routes for a registered resource.
      #
      # @param route_config [Hash] Configuration for the resource routes.
      # @param resource [Class] The resource class.
      # @return [void]
      def define_resource_routes(route_config, resource)
        concern route_config[:concern_name] do
          resources route_config[:route_name], **route_config[:route_options] do
            instance_exec(&route_config[:block]) if route_config[:block]
            define_nested_resource_routes(resource)
          end
        end
      end

      # Defines nested resource routes for a given resource.
      #
      # @param resource [Class] The parent resource class.
      # @return [void]
      def define_nested_resource_routes(resource)
        nested_configs = route_set.resource_route_config_for(*resource.has_many_association_routes)
        nested_configs.each do |nested_config|
          resources "nested_#{nested_config[:route_name]}", **nested_config[:route_options] do
            instance_exec(&nested_config[:block]) if nested_config[:block]
          end
        end
      end

      # Defines member-level interactive actions.
      #
      # @return [void]
      def define_member_interactive_actions
        member do
          get "record_actions/:interactive_action", action: :interactive_record_action,
            as: :record_action
          post "record_actions/:interactive_action", action: :commit_interactive_record_action
        end
      end

      # Defines collection-level interactive actions.
      #
      # @return [void]
      def define_collection_interactive_actions
        collection do
          get "bulk_actions/:interactive_action", action: :interactive_bulk_action,
            as: :bulk_action
          post "bulk_actions/:interactive_action", action: :commit_interactive_bulk_action

          get "resource_actions/:interactive_action", action: :interactive_resource_action,
            as: :resource_action
          post "resource_actions/:interactive_action", action: :commit_interactive_resource_action
        end
      end

      # Determines the scope parameters based on the engine configuration.
      #
      # @param engine [Class] The current engine.
      # @return [Hash] Scope name and options.
      def determine_scope_params(engine)
        scoped_entity_param_key = engine.scoped_entity_param_key if engine.scoped_entity_strategy == :path
        {
          name: scoped_entity_param_key.present? ? ":#{scoped_entity_param_key}" : "",
          options: scoped_entity_param_key.present? ? {as: scoped_entity_param_key} : {}
        }
      end
    end
  end
end

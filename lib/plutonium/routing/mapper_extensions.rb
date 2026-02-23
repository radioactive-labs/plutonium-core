# frozen_string_literal: true

module Plutonium
  module Routing
    # Prefix used for nested resource routes to disambiguate from user-defined routes
    NESTED_ROUTE_PREFIX = "nested_"

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
        route_config = route_set.register_resource(resource, options, &)
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

      # Draws routes wrapped in entity scope when using path-based entity scoping.
      #
      # @param scope_params [Hash, nil] Scope params from RouteSetExtensions, or nil if no scoping
      # @param block [Proc] The block containing route definitions.
      # @return [void]
      def draw_routes_with_entity_scope(scope_params, &block)
        if scope_params
          scope scope_params[:name], **scope_params[:options] do
            instance_exec(&block)
            materialize_resource_routes
          end
        else
          instance_exec(&block)
          materialize_resource_routes
        end
      end

      # Materializes all registered resource routes.
      #
      # @return [void]
      def materialize_resource_routes
        concerns resource_route_concern_names.sort
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
          send route_config[:route_type], route_config[:route_name], **route_config[:route_options] do
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
        # has_many associations use plural routes
        resource.routable_has_many_associations.each do |assoc_info|
          base_config = route_set.resource_route_config_for(assoc_info[:plural])[0]
          next unless base_config

          # Register with association-based key: "parent_plural/association_name"
          nested_key = "#{resource.model_name.plural}/#{assoc_info[:name]}"
          nested_config = base_config.merge(
            association_name: assoc_info[:name],
            resource_class: assoc_info[:klass]
          )
          route_set.resource_route_config_lookup[nested_key] = nested_config

          resources "#{NESTED_ROUTE_PREFIX}#{assoc_info[:name]}", **base_config[:route_options].except(:path) do
            instance_exec(&base_config[:block]) if base_config[:block]
          end
        end

        # has_one associations use singular routes
        resource.routable_has_one_associations.each do |assoc_info|
          base_config = route_set.resource_route_config_for(assoc_info[:plural])[0]
          next unless base_config

          # Register with association-based key and singular route type
          nested_key = "#{resource.model_name.plural}/#{assoc_info[:name]}"
          nested_config = base_config.merge(
            route_type: :resource,
            association_name: assoc_info[:name],
            resource_class: assoc_info[:klass]
          )
          route_set.resource_route_config_lookup[nested_key] = nested_config

          resource "#{NESTED_ROUTE_PREFIX}#{assoc_info[:name]}", **base_config[:route_options].except(:path) do
            original_collection = method(:collection)
            define_singleton_method(:collection) { |&_| } # no-op for singular resources
            instance_exec(&base_config[:block]) if base_config[:block]
            define_singleton_method(:collection, original_collection)
          end
        end
      end

      # Defines member-level interactive actions.
      #
      # @return [void]
      def define_member_interactive_actions
        member do
          get "record_actions/:interactive_action", action: :interactive_record_action,
            as: :interactive_record_action
          post "record_actions/:interactive_action", action: :commit_interactive_record_action,
            as: :commit_interactive_record_action
        end
      end

      # Defines collection-level interactive actions.
      #
      # @return [void]
      def define_collection_interactive_actions
        collection do
          get "bulk_actions/:interactive_action", action: :interactive_bulk_action,
            as: :interactive_bulk_action
          post "bulk_actions/:interactive_action", action: :commit_interactive_bulk_action,
            as: :commit_interactive_bulk_action

          get "resource_actions/:interactive_action", action: :interactive_resource_action,
            as: :interactive_resource_action
          post "resource_actions/:interactive_action", action: :commit_interactive_resource_action,
            as: :commit_interactive_resource_action
        end
      end
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module Pkg
    # The ResourceRoutesDrawer module is responsible for drawing resource routes
    # for Plutonium applications.
    module ResourceRoutesDrawer
      extend ActiveSupport::Concern

      class_methods do
        # Draws the resource routes for the application.
        #
        # This method is called internally by the Plutonium::Pkg::App module to set up
        # all the necessary routes for registered resources.
        #
        # @return [void]
        def draw_resource_routes_internal
          custom_routes_block = @custom_routes_block
          resource_register = self.resource_register
          scoped_entity_param_key = self.scoped_entity_param_key if scoped_entity_strategy == :path
          routes.draw do
            shared_resource_concerns = [:interactive_resource_actions] # TODO: make this a config parameter
            concern :interactive_resource_actions do
              # these concerns power the interactive actions feature
              member do
                get "record_actions/:interactive_action", action: :begin_interactive_resource_record_action,
                  as: :interactive_resource_record_action
                post "record_actions/:interactive_action", action: :commit_interactive_resource_record_action
              end

              collection do
                get "collection_actions/:interactive_action", action: :begin_interactive_resource_collection_action,
                  as: :interactive_resource_collection_action
                post "collection_actions/:interactive_action", action: :commit_interactive_resource_collection_action

                get "recordless_actions/:interactive_action", action: :begin_interactive_resource_recordless_action,
                  as: :interactive_resource_recordless_action
                post "recordless_actions/:interactive_action", action: :commit_interactive_resource_recordless_action
              end
            end

            resource_route_names = []
            resource_route_opts_lookup = {}
            # for each of our registered resources, we are registering the routes required
            resource_register.resources.each do |resource|
              resource_name = resource.to_s # Deeply::Namespaced::ResourceModel
              resource_controller = resource_name.pluralize.underscore # deeply/namespaced/resource_models
              resource_route = resource.model_name.plural # deeply_namespaced_resource_models
              resource_route_name = :"#{resource_route}_routes" # deeply_namespaced_resource_models_routes

              resource_route_opts = {}
              # rails is not smart enough to infer Deeply::Namespaced::ResourceModelsController from deeply_namespaced_resource_models
              # since we are heavy on namespaces, we choose to be explicit to guarantee there is no confusion
              resource_route_opts[:controller] = resource_controller
              # using collection for path is much nicer than the alternative
              # e.g. deeply/namespaced/resource_models vs deeply_namespaced_resource_models
              resource_route_opts[:path] = resource.model_name.collection
              resource_route_opts_lookup[resource_route] = resource_route_opts

              # defining our resources with concerns allows us to defer materializing till later,
              # ensuring that resource_route_opts_lookup is populated
              concern resource_route_name do
                resources resource_route, **resource_route_opts, concerns: shared_resource_concerns do
                  nested_resources_route_opts = resource_route_opts_lookup.slice(*resource.has_many_association_routes)
                  nested_resources_route_opts.each do |nested_resource_route, nested_resource_route_opts|
                    resources nested_resource_route, **nested_resource_route_opts, concerns: shared_resource_concerns
                  end
                end
              end
              resource_route_names << resource_route_name
            end

            # materialize our routes using a scope
            # if the app is scoped to an entity, ensure that the expected route param and url helper prefix are specified.

            # path   => /:entity/deeply/namespaced/resource_models/:deeply_namespaced_resource_model_id/
            # helper => entity_deeply_namespaced_resource_models_path
            scope_name = scoped_entity_param_key.present? ? ":#{scoped_entity_param_key}" : ""

            # path   => /deeply/namespaced/resource_models/:deeply_namespaced_resource_model_id/
            # helper => deeply_namespaced_resource_models_path
            scope_options = scoped_entity_param_key.present? ? {as: scoped_entity_param_key} : {}

            scope scope_name, scope_options do
              instance_exec(&custom_routes_block) if custom_routes_block.present?
              # we have to reverse sort our resource routes in order to prevent routing conflicts
              # e.g. /blogs/1 and blogs/comments cause an issue if Blog is registered before Blogs::Comment
              # attempting to load blogs/comments routes to blogs/:id which fails with a 404 since BlogsController
              # essentially performs a Blog.find('comments')
              # since the route names for these 2 will be 'blogs' and 'blog_comments',
              # reverse sorting ensures that blog_comments is registered first, preventing the issue described above
              concerns resource_route_names.sort
            end
          end
        end
      end
    end
  end
end

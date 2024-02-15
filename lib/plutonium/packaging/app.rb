module Plutonium
  module Packaging
    module App
      extend ActiveSupport::Concern
      include Package

      included do
        isolate_namespace to_s.deconstantize.constantize
      end

      class_methods do
        attr_reader :scoped_entity_class, :scoped_entity_param_key, :scoped_entity_strategy

        def scope_to_entity(entity_class, param_key: nil, strategy: :path)
          @scoped_entity_class = entity_class
          @scoped_entity_strategy = strategy
          @scoped_entity_param_key = param_key || entity_class.model_name.singular_route_key.to_sym
        end

        def scoped_to_entity?
          scoped_entity_class.present?
        end

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
          registered_resources = resource_register.map(&:to_s).sort.reverse.map(&:constantize)

          # debugger

          # scope ':entity_id/dashboard', module: :entity_resources, as: :entity do
          #   get '', to: 'index#index'
          #   concerns entity_resource_routes.sort.reverse
          #   # pu:routes:entity
          # end

          scoped_entity_param_key = self.scoped_entity_param_key
          routes.draw do
            route_drawer = -> {
              registered_resources.each do |resource|
                resource_name = resource.to_s
                resource_module = resource_name.deconstantize&.underscore
                resource_controller = resource_name.pluralize.demodulize.underscore

                route_opts = {}
                if resource_module.present?
                  route_opts[:module] = resource_module
                  route_opts[:controller] = resource_controller
                  route_opts[:path] = resource.model_name.collection
                end

                resources resource.model_name.plural, **route_opts  do
                  member do
                    get 'actions/:interactive_action', action: :begin_interactive_resource_action, as: :interactive_resource_action
                    post 'actions/:interactive_action', action: :commit_interactive_resource_action
                  end

                  collection do
                    get 'actions/:interactive_action', action: :begin_interactive_bulk_resource_action, as: :interactive_bulk_resource_action
                    post 'actions/:interactive_action', action: :commit_interactive_bulk_resource_action
                  end
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

                # TODO: test this with uncountables/irregulars
                # https://stackoverflow.com/questions/31812619/rails-routes-wrong-singular-for-resources
                # if resource.model_name.uncountable?
                #   # https://stackoverflow.com/questions/6476763/rails-3-route-appends-index-to-route-name
                #   resource resource.model_name.singular, **route_opts
                #   get "#{resource.model_name.collection}_index", action: :index,
                #                                       as: resource.model_name.route_key,
                #                                       **route_opts.slice(:module, :controller)
                # else
                # end
              end
            }

            if scoped_entity_param_key.present?
              scope ":#{scoped_entity_param_key}", as: scoped_entity_param_key do
                route_drawer.call
              end
            else
              route_drawer.call
            end
          end
        end
      end
    end
  end
end

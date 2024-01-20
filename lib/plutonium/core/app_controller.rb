module Plutonium
  module Core
    module AppController
      extend ActiveSupport::Concern

      included do
        helper_method :current_parent
        helper_method :adapt_route_args
      end

      class_methods do
        def scope_to_entity(entity_class)
          include Plutonium::Core::Controller::EntityScoped.to(entity_class)
        end
      end

      private

      def resource_presenter(resource_class)
        presenter_class = "#{current_package}::#{resource_class}Presenter".constantize
        presenter_class.new resource_context, resource_class
      end

      def policy_namespace(scope)
        [current_package.to_s.underscore.to_sym, scope]
      end

      def build_sidebar_menu
        {
          resources: current_engine.resource_register.map { |resource|
                       [resource.pluralize, url_for(resource.constantize)]
                     }.to_h
        }
      end

      def scoped_to_entity?
        false
      end

      def scoped_entity_class
        raise NotImplementedError, "this request is not scoped to an entity\n\n" \
                                   "add the `scope_to_entity MyEntityModel` directive in " \
                                   "#{current_package}::ResourceController after `boot #{current_package}` " \
                                   "or implement #scoped_entity_class"
      end

      def current_scoped_entity
        raise NotImplementedError, "this request is not scoped to an entity\n\n" \
                                   "add the `scope_to_entity MyEntityModel` directive in " \
                                   "#{current_package}::ResourceController after `boot #{current_package}` " \
                                   "or implement #current_scoped_entity"
      end

      def current_parent
        return unless parent_param_key.present?

        @current_parent ||= begin
          parent_name = parent_param_key.to_s.gsub(/_id$/, "")

          parent_scope = parent_name.classify.constantize.from_path_param(params[parent_param_key])
          parent_scope = parent_scope.for_parent(current_scoped_entity) if scoped_to_entity?
          parent_scope.first!
        end
      end

      def parent_param_key
        @parent_param_key ||= request.path_parameters.keys.reverse.find { |key| /_id$/.match? key }&.to_sym
      end

      #
      # Returns a dynamic list of args to be used with `url_for` which considers the route namespace and nesting.
      # The current entity and parent record (for nested routes) are inserted appropriately, ensuring that generated urls
      # obey the current routing.
      #
      # e.g. of route helpers that will be invoked given the output of this method
      #
      # - when invoked in a root route (/acme/dashboard/users)
      #
      # `adapt_route_args User`                   => `entity_users_*`
      # `adapt_route_args @user`                  => `entity_user_*`
      # `adapt_route_args @user, action: :edit`   => `edit_entity_user_*`
      # `adapt_route_args @user, Post             => `entity_user_posts_*`
      #
      # - when invoked in a nested route (/acme/dashboard/users/1/post/1)
      #
      # `adapt_route_args Post`                   => `entity_user_posts_*`
      # `adapt_route_args @post`                  => `entity_user_post_*`
      # `adapt_route_args @post, action: :edit`   => `edit_entity_user_post_*`
      #
      # @param [Class, ApplicationRecord] *args arguments you would normally pass to `url_for`
      # @param [Symbol] action optional action to invoke e.g. :new, :edit
      #
      # @return [Array[Class, ApplicationRecord, Symbol]] args to pass to `url_for`
      #
      def adapt_route_args(*args, action: nil, use_parent: true, **kwargs)
        # If the last item is a class and an action is passed e.g. `adapt_route_args User, action: :new`,
        # it must be converted into a symbol to generate the appropriate helper i.e `new_user_*`
        resource = args.pop
        resource = resource.model_name.singular_route_key.to_sym if action.present? && resource.is_a?(Class)
        args.push resource

        parent = use_parent ? current_parent : nil

        base_args = if scoped_to_entity?
          [action, current_scoped_entity.becomes(scoped_entity_class), parent]
        else
          [action, parent]
        end

        # rails compacts this list. no need to handle nils
        base_args + args + [**kwargs]
      end
    end
  end
end

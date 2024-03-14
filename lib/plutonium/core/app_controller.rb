module Plutonium
  module Core
    module AppController
      extend ActiveSupport::Concern
      include Plutonium::Core::Controllers::EntityScoping
      include Plutonium::Core::Controllers::Bootable

      included do
        helper_method :current_parent
        helper_method :resource_url_for
        helper_method :registered_resources
        helper_method :resource_url_args_for
      end

      private

      def resource_presenter(resource_class, resource_record)
        presenter_class = "#{current_package}::#{resource_class}Presenter".constantize
        presenter_class.new resource_context, resource_record
      end

      def resource_query_object(resource_class, params)
        query_object_class = "#{current_package}::#{resource_class}QueryObject".constantize
        query_object_class.new resource_context, params
      end

      def policy_namespace(scope)
        [current_package.to_s.underscore.to_sym, scope]
      end

      # # Menu Builder
      # def build_namespace_node(namespaces, resource, parent)
      #   current = namespaces.shift
      #   if namespaces.size.zero?
      #     parent[current.pluralize] = url_for(resource_url_for(resource, use_parent: false))
      #   else
      #     parent[current] = {}
      #     build_namespace_node(namespaces, resource, parent[current])
      #   end
      #   # parent.sort!
      # end

      # def build_namespace_tree(resources)
      #   root = {}
      #   resources.each do |resource|
      #     namespaces = resource.name.split("::")
      #     build_namespace_node(namespaces, resource, root)
      #   end
      #   root
      # end

      # def build_sidebar_menu
      #   build_namespace_tree(current_engine.resource_register)
      # end

      def registered_resources
        current_engine.resource_register
      end
      # Menu Builder

      def current_parent
        return unless parent_route_param.present?

        @current_parent ||= begin
          parent_route_key = parent_route_param.to_s.gsub(/_id$/, "").to_sym
          parent_class = current_engine.registered_resource_route_key_lookup[parent_route_key]
          parent_scope = parent_class.from_path_param(params[parent_route_param])
          parent_scope = parent_scope.associated_with(current_scoped_entity) if scoped_to_entity?
          parent_scope.first!
        end
      end

      def parent_route_param
        @parent_route_param ||= request.path_parameters.keys.reverse.find { |key| /_id$/.match? key }
      end

      #
      # Returns the attribute on the resource if there is a current parent and the resource has a belongs to association to it
      #
      def parent_input_param
        return unless current_parent.present?

        resource_class.reflect_on_all_associations(:belongs_to).find { |assoc| assoc.klass == current_parent.class }&.name&.to_sym
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
      # `resource_url_args_for User`                   => `entity_users_*`
      # `resource_url_args_for @user`                  => `entity_user_*`
      # `resource_url_args_for @user, action: :edit`   => `edit_entity_user_*`
      # `resource_url_args_for @user, Post             => `entity_user_posts_*`
      #
      # - when invoked in a nested route (/acme/dashboard/users/1/post/1)
      #
      # `resource_url_args_for Post`                   => `entity_user_posts_*`
      # `resource_url_args_for @post`                  => `entity_user_post_*`
      # `resource_url_args_for @post, action: :edit`   => `edit_entity_user_post_*`
      #
      # @param [Class, ApplicationRecord] *args arguments you would normally pass to `url_for`
      # @param [Symbol] action optional action to invoke e.g. :new, :edit
      #
      # @return [Array[Class, ApplicationRecord, Symbol]] args to pass to `url_for`
      #
      def resource_url_args_for(*args, action: nil, use_parent: true, **kwargs)
        # If the last item is a class and the action is :new e.g. `resource_url User, action: :new`,
        # it must be converted into a symbol to generate the appropriate helper i.e `new_user_*`
        # to match the url helper generated by `resources :users`
        resource = args.pop
        resource = resource.model_name.singular_route_key.to_sym if action == :new && resource.is_a?(Class)
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

      def resource_url_for(...)
        send(current_package.name.underscore.to_sym).url_for(resource_url_args_for(...))
      end
    end
  end
end

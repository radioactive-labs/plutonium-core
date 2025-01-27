module Plutonium
  module Core
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Core::Controllers::Bootable
      include Plutonium::Core::Controllers::EntityScoping
      include Plutonium::Core::Controllers::Authorizable

      included do
        add_flash_types :success, :warning, :error

        before_action do
          next unless defined?(ActiveStorage)

          ActiveStorage::Current.url_options = {protocol: request.protocol, host: request.host, port: request.port}
        end

        helper Plutonium::Helpers
        helper_method :make_page_title, :resource_url_for, :resource_url_args_for, :root_path

        append_view_path File.expand_path("app/views", Plutonium.root)
        layout -> { turbo_frame_request? ? false : "resource" }
        helper_method :registered_resources
      end

      private

      def set_page_title(page_title)
        @page_title = page_title
      end

      def make_page_title(title, app_name: helpers.application_name)
        [title.presence, app_name].compact.join(" | ")
      end

      #
      # Returns a dynamic list of args to be used with `url_for`, which considers the route namespace and nesting.
      # The current entity and parent record (for nested routes) are inserted appropriately, ensuring that generated URLs
      # obey the current routing.
      #
      # e.g., of route helpers that will be invoked given the output of this method
      #
      # - when invoked in a root route (/acme/dashboard/users)
      #
      # `resource_url_args_for User`                   => `entity_users_*`
      # `resource_url_args_for @user`                  => `entity_user_*`
      # `resource_url_args_for @user, action: :edit`   => `edit_entity_user_*`
      # `resource_url_args_for @user, Post`            => `entity_user_posts_*`
      #
      # - when invoked in a nested route (/acme/dashboard/users/1/post/1)
      #
      # `resource_url_args_for Post`                   => `entity_user_posts_*`
      # `resource_url_args_for @post`                  => `entity_user_post_*`
      # `resource_url_args_for @post, action: :edit`   => `edit_entity_user_post_*`
      #
      # @param [Class, ApplicationRecord] *args arguments you would normally pass to `url_for`
      # @param [Symbol] action optional action to invoke, e.g., :new, :edit
      # @param [ApplicationRecord] parent the parent record for nested routes, if any
      # @param [Hash] kwargs additional keyword arguments to pass to `url_for`
      #
      # @return [Hash] args to pass to `url_for`
      #
      def resource_url_args_for(*args, action: nil, parent: nil, **kwargs)
        url_args = {**kwargs, action: action}.compact

        controller_chain = [current_package&.to_s].compact
        [*args].compact.each_with_index do |element, index|
          if element.is_a?(Class)
            controller_chain << element.to_s.pluralize
          else
            controller_chain << element.class.to_s.pluralize
            if index == args.length - 1
              resource_route_config = current_engine.routes.resource_route_config_for(element.model_name.plural)[0]
              url_args[:id] = element.to_param unless resource_route_config[:route_type] == :resource
              url_args[:action] ||= :show
            else
              url_args[element.model_name.singular_route_key.to_sym] = element.to_param
            end
          end
        end
        url_args[:controller] = "/#{controller_chain.join("::").underscore}"

        url_args[:"#{parent.model_name.singular_route_key}_id"] = parent.to_param if parent.present?
        if scoped_to_entity? && scoped_entity_strategy == :path
          url_args[scoped_entity_param_key] = current_scoped_entity
        end

        url_args
      end

      def resource_url_for(...)
        args = resource_url_args_for(...)
        if current_package.present?
          send(current_package.name.underscore.to_sym).url_for(args)
        else
          url_for(args)
        end
      end

      def root_path(*)
        return send(:"#{scoped_entity_param_key}_root_path", *) if scoped_to_entity? && scoped_entity_strategy == :path

        super
      end

      def registered_resources
        current_engine.resource_register.resources
      end
    end
  end
end

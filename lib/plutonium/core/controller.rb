module Plutonium
  module Core
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Core::Controllers::Bootable
      include Plutonium::Core::Controllers::EntityScoping
      include Plutonium::Core::Controllers::Authorizable

      included do
        add_flash_types :success, :warning, :error
        
        protect_from_forgery with: :null_session, if: -> { request.headers['Authorization'].present? }

        before_action do
          next unless defined?(ActiveStorage)

          ActiveStorage::Current.url_options = {protocol: request.protocol, host: request.host, port: request.port}
        end

        helper Plutonium::Helpers
        helper_method :make_page_title, :resource_url_for,
          :resource_url_args_for, :root_path, :app_name, :route_options_to_url

        append_view_path File.expand_path("app/views", Plutonium.root)
        layout -> { turbo_frame_request? ? false : "resource" }
        helper_method :registered_resources
      end

      private

      def set_page_title(page_title)
        @page_title = page_title
      end

      def make_page_title(title)
        [title.presence, app_name].compact.join(" | ")
      end

      def app_name
        helpers.application_name
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
            # For STI models, use the base class for routing if the specific class isn't registered
            model_class = element.class
            if model_class.respond_to?(:base_class) && model_class != model_class.base_class
              # Check if the STI model is registered, if not use base class
              route_configs = current_engine.routes.resource_route_config_for(model_class.model_name.plural)
              model_class = model_class.base_class if route_configs.empty?
            end

            controller_chain << model_class.to_s.pluralize
            if index == args.length - 1
              resource_route_config = current_engine.routes.resource_route_config_for(model_class.model_name.plural)[0]
              url_args[:id] = element.to_param unless resource_route_config[:route_type] == :resource
              url_args[:action] ||= :show
            else
              url_args[model_class.to_s.underscore.singularize.to_sym] = element.to_param
            end
          end
        end
        url_args[:controller] = "/#{controller_chain.join("::").underscore}"

        url_args[:"#{parent.model_name.singular}_id"] = parent.to_param if parent.present?
        if scoped_to_entity? && scoped_entity_strategy == :path
          url_args[scoped_entity_param_key] = current_scoped_entity
        end

        # Preserve the request format unless explicitly specified
        if !url_args.key?(:format) && request.present? && request.format.present? && request.format.symbol != :html
          url_args[:format] = request.format.symbol
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

      # Converts RouteOptions into a URL using the appropriate URL resolver.
      #
      # This method takes a RouteOptions object and generates a URL based on the url_resolver
      # specified within the RouteOptions. It supports different resolution strategies:
      # - If the route_options responds to :to_proc, executes it as a Proc in the current instance context
      # - For :resource_url_for resolver, generates a URL using the provided subject
      # - For :url_for resolver, generates a URL using only the url_options from route_options
      #
      # @param [RouteOptions, #to_proc] route_options The RouteOptions object or callable to convert to a URL
      # @param [Object] subject The subject to use when generating URLs with :resource_url_for
      # @return [String] The generated URL
      # @raise [NotImplementedError] If an unsupported url_resolver is specified
      def route_options_to_url(route_options, subject = nil)
        url_resolver = route_options.url_resolver

        if url_resolver == :resource_url_for
          raise ArgumentError, "subject is required when url_resolver is: :resource_url_for" unless subject
          resource_url_for(subject, *route_options.url_args, **route_options.url_options)
        elsif url_resolver == :url_for
          url_for(**route_options.url_options)
        elsif url_resolver.respond_to?(:to_proc)
          instance_exec(subject, &url_resolver)
        else
          raise NotImplementedError, "url_resolver: #{url_resolver}"
        end
      end
    end
  end
end

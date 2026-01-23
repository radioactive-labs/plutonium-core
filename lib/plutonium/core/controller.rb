module Plutonium
  module Core
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Core::Controllers::Bootable
      include Plutonium::Core::Controllers::EntityScoping
      include Plutonium::Core::Controllers::Authorizable
      include Plutonium::Core::Controllers::AssociationResolver

      included do
        add_flash_types :success, :warning, :error

        protect_from_forgery with: :null_session, if: -> { request.headers["Authorization"].present? }

        rescue_from ::ActionPolicy::Unauthorized do |exception|
          respond_to do |format|
            format.any(:html, :turbo_stream) do
              raise exception
            end
            format.any do
              @errors = ActiveModel::Errors.new(exception.policy.record)
              @errors.add(:base, :unauthorized, message: exception.result.message)
              render "errors", status: :forbidden
            end
          end
        end

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
      # - with explicit association (for multiple associations to same class)
      #
      # `resource_url_args_for :authored_posts, parent: @user` => `entity_user_authored_posts_*`
      #
      # @param [Class, ApplicationRecord, Symbol] *args arguments you would normally pass to `url_for`.
      #   When parent is specified, can be a Symbol to explicitly name the association.
      # @param [Symbol] action optional action to invoke, e.g., :new, :edit
      # @param [ApplicationRecord] parent the parent record for nested routes, if any
      # @param [Symbol] association explicit association name (when multiple associations to same class)
      # @param [Hash] kwargs additional keyword arguments to pass to `url_for`
      #
      # @return [Hash] args to pass to `url_for`
      #
      def resource_url_args_for(*args, action: nil, parent: nil, association: nil, package: nil, **kwargs)
        target_package = package || current_package

        # For nested resources, use named route helpers to avoid Rails param recall ambiguity
        if parent.present?
          assoc_name = if args.first.is_a?(Symbol)
            args.first
          else
            association || resolve_association(args.first, parent)
          end

          nested_route_key = "#{parent.class.model_name.plural}/#{assoc_name}"
          route_config = current_engine.routes.resource_route_config_for(nested_route_key)[0]

          if route_config
            return build_nested_resource_url_args(
              args.first,
              parent: parent,
              association_name: assoc_name,
              route_config: route_config,
              action: action,
              **kwargs
            )
          end
        end

        # Top-level resource: build controller/action hash for url_for
        build_top_level_resource_url_args(*args, action: action, parent: parent, association: association, package: target_package, **kwargs)
      end

      def resource_url_for(*args, package: nil, **kwargs)
        url_args = resource_url_args_for(*args, package: package, **kwargs)
        url_helpers = route_url_helpers_for(package)

        if url_args[:_named_route]
          url_helpers.send(url_args[:_named_route], *url_args[:_args], **url_args[:_options])
        else
          url_helpers.url_for(url_args)
        end
      end

      def route_url_helpers_for(package = nil)
        pkg = package || current_package
        pkg.present? ? send(pkg.name.underscore.to_sym) : current_engine.routes.url_helpers
      end

      private

      def build_nested_resource_url_args(element, parent:, association_name:, route_config:, action: nil, **kwargs)
        prefix = Plutonium::Routing::NESTED_ROUTE_PREFIX
        is_singular = route_config[:route_type] == :resource

        # For singular resources (has_one), Class/Symbol/nil without action means "no record exists" -> default to :new
        if is_singular && (element.is_a?(Class) || element.is_a?(Symbol) || element.nil?) && action.nil?
          action = :new
        end

        # Build the named helper: e.g., "blogging_post_nested_post_metadata_path"
        parent_singular = parent.model_name.singular
        nested_resource_name = "#{prefix}#{association_name}"

        # Determine if this is a collection action (no specific record)
        no_record = element.is_a?(Class) || element.is_a?(Symbol) || element.nil?

        # Determine the helper name based on action and route type
        # For singular routes (has_one), always use the association name as-is (no singularize)
        # For plural routes (has_many):
        #   - :index action uses plural (blogging_post_nested_comments)
        #   - :new action uses singular (new_blogging_post_nested_comment)
        #   - member actions (show/edit/destroy) use singular (blogging_post_nested_comment)
        helper_base = if is_singular
          "#{parent_singular}_#{nested_resource_name}"
        elsif action == :index || (no_record && action != :new)
          "#{parent_singular}_#{nested_resource_name}"
        else
          "#{parent_singular}_#{nested_resource_name.to_s.singularize}"
        end

        helper_suffix = case action
        when :new then "new_"
        when :edit then "edit_"
        else ""
        end

        helper_name = :"#{helper_suffix}#{helper_base}_path"

        # Build the arguments for the helper
        helper_args = [parent.to_param]
        # Include element ID for plural routes (has_many) when we have a record instance
        unless is_singular || no_record
          helper_args << element.to_param
        end

        # Build URL options
        url_options = kwargs.dup
        if !url_options.key?(:format) && request.present? && request.format.present? && !request.format.symbol.in?([:html, :turbo_stream])
          url_options[:format] = request.format.symbol
        end

        {_named_route: helper_name, _args: helper_args, _options: url_options}
      end

      def build_top_level_resource_url_args(*args, action: nil, parent: nil, association: nil, package: nil, **kwargs)
        url_args = {**kwargs, action: action}.compact

        controller_chain = [package&.to_s].compact
        [*args].compact.each_with_index do |element, index|
          if element.is_a?(Symbol)
            raise ArgumentError, "parent is required when using symbol association name" unless parent

            assoc = parent.class.reflect_on_association(element)
            raise ArgumentError, "Unknown association :#{element} on #{parent.class}" unless assoc

            controller_chain << assoc.klass.to_s.pluralize
            url_args[:action] ||= :index if index == args.length - 1
          elsif element.is_a?(Class)
            controller_chain << element.to_s.pluralize
            url_args[:action] ||= :index if index == args.length - 1 && parent.present?
          else
            model_class = element.class
            if model_class.respond_to?(:base_class) && model_class != model_class.base_class
              route_configs = current_engine.routes.resource_route_config_for(model_class.model_name.plural)
              model_class = model_class.base_class if route_configs.empty?
            end

            controller_chain << model_class.to_s.pluralize
            if index == args.length - 1
              route_key = if parent.present?
                assoc_name = association || resolve_association(element, parent)
                "#{parent.class.model_name.plural}/#{assoc_name}"
              else
                model_class.model_name.plural
              end
              resource_route_config = current_engine.routes.resource_route_config_for(route_key)[0]
              is_singular = resource_route_config&.dig(:route_type) == :resource
              url_args[:id] = element.to_param unless is_singular
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

        if !url_args.key?(:format) && request.present? && request.format.present? && !request.format.symbol.in?([:html, :turbo_stream])
          url_args[:format] = request.format.symbol
        end

        url_args
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

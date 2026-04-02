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
        element = args.first

        raise ArgumentError, "parent is required when using symbol association name" if element.is_a?(Symbol) && parent.nil?

        # For nested resources, use named route helpers to avoid Rails param recall ambiguity
        if parent.present?
          assoc_name = if element.is_a?(Symbol)
            element
          else
            association || resolve_association(element, parent)
          end

          nested_route_key = "#{parent.class.model_name.plural}/#{assoc_name}"
          route_config = current_engine.routes.resource_route_config_for(nested_route_key)[0]

          if route_config
            return build_nested_resource_url_args(
              element,
              parent: parent,
              association_name: assoc_name,
              route_config: route_config,
              action: action,
              **kwargs
            )
          end
        end

        # Top-level resource: use named route helpers
        build_top_level_resource_url_args(element, action: action, **kwargs)
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
        # For plural parent resources (resources :posts), nested routes use the singular member name (post_nested_...)
        # For singular parent resources (resource :entities), nested routes use the route name as-is (entities_nested_...)
        parent_is_singular_route = current_engine.routes.singular_resource_route?(parent.model_name.plural)
        parent_prefix = parent_is_singular_route ? parent.model_name.plural : parent.model_name.singular
        nested_resource_name = "#{prefix}#{association_name}"

        # Determine if this is a collection action (no specific record)
        no_record = element.is_a?(Class) || element.is_a?(Symbol) || element.nil?

        # Determine the helper name based on action and route type
        # For singular routes (has_one), always use the association name as-is (no singularize)
        # For plural routes (has_many):
        #   - :index/:create actions use plural (blogging_post_nested_comments) - collection routes
        #   - :new action uses singular (new_blogging_post_nested_comment)
        #   - member actions (show/edit/update/destroy) use singular (blogging_post_nested_comment)
        is_collection_action = action == :index || action == :create || (no_record && action != :new)
        helper_base = if is_singular || is_collection_action
          "#{parent_prefix}_#{nested_resource_name}"
        else
          "#{parent_prefix}_#{nested_resource_name.to_s.singularize}"
        end

        # Only add helper prefix for actions that have named route helpers (new, edit)
        # :create/:update use HTTP method to differentiate, not route helper prefix
        helper_suffix = case action
        when :show, :create, :update, nil then ""
        else "#{action}_"
        end

        # Add entity scope prefix for path-based entity scoping
        entity_prefix = if scoped_to_entity? && scoped_entity_strategy == :path
          "#{scoped_entity_param_key}_"
        end

        helper_name = :"#{helper_suffix}#{entity_prefix}#{helper_base}_path"

        # Build the arguments for the helper
        helper_args = []
        # Add entity scope param for path-based entity scoping
        helper_args << current_scoped_entity.to_param if entity_prefix
        # Singular parent resources (resource :entity) have no :id param in the route
        helper_args << parent.to_param unless parent_is_singular_route
        # Include element ID for plural routes (has_many) when we have a record instance
        # Skip ID for collection actions (:index, :create) which don't need a member ID
        unless is_singular || no_record || is_collection_action
          helper_args << element.to_param
        end

        # Build URL options
        url_options = kwargs.dup
        if !url_options.key?(:format) && request.present? && request.format.present? && !request.format.symbol.in?([:html, :turbo_stream])
          url_options[:format] = request.format.symbol
        end

        {_named_route: helper_name, _args: helper_args, _options: url_options}
      end

      # Build URL args for top-level resources using named route helpers.
      # This avoids Rails url_for ambiguity when multiple routes map to the same controller
      # (e.g., both /widgets/:id and /organization/nested_widgets/:id resolve to widgets#show).
      def build_top_level_resource_url_args(element, action: nil, **kwargs)
        # Resolve the model class for the target resource
        if element.is_a?(Class)
          model_class = element
        elsif element
          model_class = element.class
          if model_class.respond_to?(:base_class) && model_class != model_class.base_class
            route_configs = current_engine.routes.resource_route_config_for(model_class.model_name.plural)
            model_class = model_class.base_class if route_configs.empty?
          end
        end

        route_key = model_class.model_name.plural
        is_singular = current_engine.routes.singular_resource_route?(route_key)
        no_record = element.is_a?(Class) || element.nil?

        # Default action based on context
        action ||= if no_record
          is_singular ? :show : :index
        else
          :show
        end

        # Build named route helper, mirroring the pattern used by build_nested_resource_url_args.
        # e.g., "organization_scope_widgets" (collection), "organization_scope_widget" (member),
        #        "edit_organization_scope_widget" (edit action)
        is_collection_action = action == :index || action == :create || (no_record && action != :new)
        helper_base = if is_singular || is_collection_action
          model_class.model_name.plural
        else
          model_class.model_name.singular
        end

        # For uncountable model names (plural == singular), Rails adds _index suffix
        # to collection route names to disambiguate from member routes.
        uncountable_index_suffix = if is_collection_action && !is_singular && model_class.model_name.plural == model_class.model_name.singular
          "_index"
        end

        helper_suffix = case action
        when :show, :index, :create, :update then ""
        else "#{action}_"
        end

        entity_prefix = if scoped_to_entity? && scoped_entity_strategy == :path
          "#{scoped_entity_param_key}_"
        end

        helper_name = :"#{helper_suffix}#{entity_prefix}#{helper_base}#{uncountable_index_suffix}_path"

        # Build the positional arguments for the helper
        helper_args = []
        helper_args << current_scoped_entity.to_param if entity_prefix
        unless is_singular || no_record || is_collection_action
          helper_args << element.to_param
        end

        # Build URL options
        url_options = kwargs.dup
        if !url_options.key?(:format) && request.present? && request.format.present? && !request.format.symbol.in?([:html, :turbo_stream])
          url_options[:format] = request.format.symbol
        end

        {_named_route: helper_name, _args: helper_args, _options: url_options}
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

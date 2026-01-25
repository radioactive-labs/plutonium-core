require "action_controller"
require "pagy"
require_relative "../routing/mapper_extensions"

module Plutonium
  module Resource
    # Controller module to handle resource actions and concerns
    module Controller
      extend ActiveSupport::Concern
      include Pagy::Backend
      include Plutonium::Core::Controller
      include Plutonium::Resource::Controllers::Defineable
      include Plutonium::Resource::Controllers::Authorizable
      include Plutonium::Resource::Controllers::Presentable
      include Plutonium::Resource::Controllers::Queryable
      include Plutonium::Resource::Controllers::CrudActions
      include Plutonium::Resource::Controllers::InteractiveActions

      included do
        # https://github.com/ddnexus/pagy/blob/master/docs/extras/headers.md#headers
        after_action { pagy_headers_merge(@pagy) if @pagy }

        helper_method :current_parent, :current_nested_association, :resource_record!, :resource_record?, :resource_param_key, :resource_class

        # Use class_attribute for proper inheritance
        class_attribute :_resource_class, instance_accessor: false
      end

      class_methods do
        # include Plutonium::Lib::SmartCache

        # Sets the resource class for the controller
        # @param [ActiveRecord::Base] resource_class The resource class
        def controller_for(resource_class)
          self._resource_class = resource_class
        end

        # Gets the resource class for the controller
        # @return [ActiveRecord::Base] The resource class
        def resource_class
          return _resource_class if _resource_class

          base_name = name.to_s.gsub(/^#{current_package}::/, "").gsub(/Controller$/, "")
          singularized_name = base_name.singularize.camelize

          # Use singularize + camelize to respect custom inflections
          singularized_name.constantize
        rescue NameError
          # Check if inflection is the issue (e.g., PostMetadata -> PostMetadatum)
          if base_name != singularized_name && base_name.camelize.safe_constantize
            raise NameError, <<~MSG.squish
              Failed to determine the resource class for #{name}.
              Rails singularized "#{base_name}" to "#{singularized_name}", but "#{base_name.camelize}" exists.
              Add an inflection rule to config/initializers/inflections.rb.
              See: https://radioactive-labs.github.io/plutonium-core/guides/troubleshooting
            MSG
          end

          raise NameError, "Failed to determine the resource class. Please call `controller_for(MyResource)` in #{name}."
        end
        # memoize_unless_reloading :resource_class
      end

      private

      # Override to prepend parent label for nested resources in the browser tab title.
      # e.g., "John Doe › Authored Comments"
      def set_page_title(page_title)
        @page_title = if current_parent
          "#{current_parent.to_label} › #{page_title}"
        else
          page_title
        end
      end

      def resource_class
        if current_parent
          # Nested route: resource_class must come from route config
          current_resource_route_config&.dig(:resource_class) or
            raise "No resource_class found in route config for nested route"
        else
          self.class.resource_class
        end
      end

      def resource_record_relation
        @resource_record_relation ||= begin
          resource_route_config = current_resource_route_config
          if resource_route_config[:route_type] == :resource
            current_authorized_scope
          elsif params[:id]
            current_authorized_scope.from_path_param(params[:id])
          else
            current_authorized_scope.none
          end
        end
      end

      def current_resource_route_config
        @current_resource_route_config ||= if current_parent
          current_engine.routes.resource_route_config_lookup["#{current_parent.class.model_name.plural}/#{current_nested_association}"]
        else
          current_engine.routes.resource_route_config_for(resource_class.model_name.plural)[0]
        end
      end

      # Extracts the association name from the current nested route
      # e.g., for route /posts/:post_id/nested_comments, returns :comments
      # @return [Symbol, nil] The association name
      def current_nested_association
        return unless parent_route_param

        # Extract from request path: find the nested_* segment after the parent param
        # e.g., /posts/123/nested_comments/456 => "comments"
        # Note: Strip format extension (.json, .xml, etc.) from the segment
        prefix = Plutonium::Routing::NESTED_ROUTE_PREFIX
        path_segments = request.path.split("/")
        nested_segment = path_segments.find { |seg| seg.start_with?(prefix) }
        return unless nested_segment

        # Remove prefix and any format extension (e.g., "nested_versions.json" -> "versions")
        association_name = nested_segment.delete_prefix(prefix).sub(/\.\w+\z/, "")
        association_name.to_sym
      end

      def resource_record!
        @resource_record ||= resource_record_relation.first!
      end

      def resource_record?
        @resource_record ||= resource_record_relation.first
      end

      # Returns the submitted resource parameters
      # @return [Hash] The submitted resource parameters
      def submitted_resource_params
        # Use existing record (cloned) for context during param extraction, or new instance for create
        extraction_record = resource_record?&.dup || resource_class.new
        @submitted_resource_params ||= build_form(extraction_record).extract_input(params, view_context:)[resource_param_key.to_sym].compact
      end

      # Returns the resource parameters, including scoped and parent parameters
      # @return [Hash] The resource parameters
      def resource_params
        @resource_params ||= begin
          input_params = submitted_resource_params.dup
          override_entity_scoping_params(input_params)
          override_parent_params(input_params)

          input_params
        end
      end

      # Returns the resource parameter key
      # @return [Symbol] The resource parameter key (for form params)
      def resource_param_key
        resource_class.model_name.param_key
      end

      # Creates a resource context
      # @return [Plutonium::Resource::Context] The resource context
      def resource_context
        Plutonium::Resource::Context.new(
          resource_class:,
          parent: current_parent,
          scope: scoped_to_entity? ? current_scoped_entity : nil
        )
      end

      # Creates a resource definition
      # @param [Class] resource_class The resource class
      # @return [Object] The resource definition
      def resource_definition(resource_class)
        definition_class = [current_package, "#{resource_class}Definition"].compact.join("::").constantize
        definition_class.new
      rescue NameError
        super
      end

      # Applies submitted resource params if they have been passed
      def maybe_apply_submitted_resource_params!
        ensure_get_request
        resource_record!.attributes = submitted_resource_params if params[resource_param_key]
      end

      # Returns the current parent based on path parameters
      # @return [ActiveRecord::Base, nil] The current parent
      def current_parent
        return unless parent_route_param

        @current_parent ||= begin
          parent_route_key = parent_route_param.to_s.gsub(/_id$/, "").to_sym
          parent_class = current_engine.resource_register.route_key_lookup[parent_route_key]
          parent_scope = authorized_scope(parent_class.all, context: {entity_scope: entity_scope_for_authorize})
          parent_scope = parent_scope.from_path_param(params[parent_route_param])
          current_parent = parent_scope.first!
          authorize! current_parent, to: :read?
          current_parent
        end
      end

      # Returns the parent route parameter
      # @return [Symbol, nil] The parent route parameter
      def parent_route_param
        @parent_route_param ||= request.path_parameters.keys.reverse.find { |key| /_id$/.match? key }
      end

      # Returns the parent input parameter (the belongs_to association name on the child)
      # Finds the belongs_to association on the child that matches the parent's foreign key
      # @return [Symbol, nil] The parent input parameter
      def parent_input_param
        return unless current_parent

        unless current_nested_association
          raise "parent exists but current_nested_association is nil - routing misconfiguration"
        end

        parent_assoc = current_parent.class.reflect_on_association(current_nested_association)
        unless parent_assoc
          raise "#{current_parent.class} does not have association :#{current_nested_association}"
        end

        # Try inverse_of first (if explicitly set)
        return parent_assoc.inverse_of.name.to_sym if parent_assoc.inverse_of

        # Fall back to finding belongs_to by foreign key
        foreign_key = parent_assoc.foreign_key.to_s
        child_assoc = resource_class.reflect_on_all_associations(:belongs_to).find do |assoc|
          assoc.foreign_key.to_s == foreign_key && assoc.klass == current_parent.class
        end
        child_assoc&.name&.to_sym
      end

      # Ensures the method is a GET request
      def ensure_get_request
        unless request.method == "GET"
          raise "🚨🚨🚨 This should be called from actions that are not persisting this data"
        end
      end

      # Overrides entity scoping parameters
      # @param [Hash] input_params The input parameters
      def override_entity_scoping_params(input_params)
        if scoped_to_entity?
          if input_params.key?(scoped_entity_param_key) || resource_class.method_defined?(:"#{scoped_entity_param_key}=")
            input_params[scoped_entity_param_key] = current_scoped_entity
          end

          if input_params.key?(:"#{scoped_entity_param_key}_id") || resource_class.method_defined?(:"#{scoped_entity_param_key}_id=")
            input_params[:"#{scoped_entity_param_key}_id"] = current_scoped_entity.id
          end
        end
      end

      # Overrides parent parameters
      # @param [Hash] input_params The input parameters
      def override_parent_params(input_params)
        if current_parent
          if input_params.key?(parent_input_param) || resource_class.method_defined?(:"#{parent_input_param}=")
            input_params[parent_input_param] = current_parent
          end

          if input_params.key?(:"#{parent_input_param}_id") || resource_class.method_defined?(:"#{parent_input_param}_id=")
            input_params[:"#{parent_input_param}_id"] = current_parent.id
          end
        end
      end

      # Constructs resource URL arguments
      # @param [Array] args The URL arguments
      # @param [Hash] kwargs The keyword arguments
      # @return [Array] The URL arguments
      def resource_url_args_for(*, **kwargs)
        kwargs[:parent] = current_parent unless kwargs.key?(:parent)
        # Pass the current association when in a nested context
        if current_parent && !kwargs.key?(:association) && current_nested_association
          kwargs[:association] = current_nested_association
        end
        super
      end
    end
  end
end

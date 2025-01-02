require "action_controller"
require "pagy"

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

        helper_method :current_parent, :resource_record!, :resource_record?, :resource_param_key, :resource_class
      end

      class_methods do
        # include Plutonium::Lib::SmartCache

        # Sets the resource class for the controller
        # @param [ActiveRecord::Base] resource_class The resource class
        def controller_for(resource_class)
          @resource_class = resource_class
        end

        # Gets the resource class for the controller
        # @return [ActiveRecord::Base] The resource class
        def resource_class
          return @resource_class if @resource_class

          name.to_s.gsub(/^#{current_package}::/, "").gsub(/Controller$/, "").classify.constantize
        rescue NameError
          raise NameError, "Failed to determine the resource class. Please call `controller_for(MyResource)` in #{name}."
        end
        # memoize_unless_reloading :resource_class
      end

      private

      def resource_class
        self.class.resource_class
      end

      def resource_record_relation
        @resource_record_relation ||= begin
          resource_route_config = current_engine.routes.resource_route_config_for(resource_class.model_name.plural)[0]
          if resource_route_config[:route_type] == :resource
            current_authorized_scope
          elsif params[:id]
            current_authorized_scope.from_path_param(params[:id])
          else
            current_authorized_scope.none
          end
        end
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
        @submitted_resource_params ||= build_form(resource_class.new).extract_input(params, view_context:)[resource_param_key.to_sym]
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
      # @return [Symbol] The resource parameter key
      def resource_param_key
        resource_class.model_name.singular_route_key
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
          parent_scope = if scoped_to_entity?
            parent_class.associated_with(current_scoped_entity)
          else
            parent_class.all
          end
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

      # Returns the parent input parameter
      # @return [Symbol, nil] The parent input parameter
      def parent_input_param
        return unless current_parent

        resource_class.reflect_on_all_associations(:belongs_to).find { |assoc| assoc.klass.name == current_parent.class.name }&.name&.to_sym
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
        super
      end
    end
  end
end

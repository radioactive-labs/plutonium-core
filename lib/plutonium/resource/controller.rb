require "action_controller"
require "pagy"

require File.expand_path("refinements/parameter_refinements", Plutonium.lib_root)
using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Resource
    # Controller module to handle resource actions and concerns
    module Controller
      extend ActiveSupport::Concern
      include Pagy::Backend
      include Plutonium::Core::Controllers::Base
      include Plutonium::Core::Controllers::Authorizable
      include Plutonium::Core::Controllers::Presentable
      include Plutonium::Core::Controllers::Queryable
      include Plutonium::Core::Controllers::CrudActions
      include Plutonium::Core::Controllers::InteractiveActions

      included do
        class_attribute :resource_class, instance_writer: false, instance_predicate: false

        # https://github.com/ddnexus/pagy/blob/master/docs/extras/headers.md#headers
        after_action { pagy_headers_merge(@pagy) if @pagy }

        helper_method :current_parent, :resource_record, :resource_param_key, :resource_class
      end

      class_methods do
        # Sets the resource class for the controller
        # @param [Class] resource_class The resource class
        def controller_for(resource_class)
          self.resource_class = resource_class
        end
      end

      private

      # Creates a policy context
      # @return [Plutonium::Resource::PolicyContext] The policy context
      def policy_context
        Plutonium::Resource::PolicyContext.new(
          user: current_user,
          resource_context: resource_context
        )
      end

      # Returns the resource record based on path parameters
      # @return [ActiveRecord::Base, nil] The resource record
      def resource_record
        @resource_record ||= policy_scope(resource_class).from_path_param(params[:id]).first! if params[:id].present?
        @resource_record
      end

      # Returns the submitted resource parameters
      # @return [Hash] The submitted resource parameters
      def submitted_resource_params
        @submitted_resource_params ||= begin
          strong_parameters = resource_class.strong_parameters_for(*permitted_attributes)
          params.require(resource_param_key).permit(*strong_parameters).nilify.to_h
        end
      end

      # Returns the resource parameters, including scoped and parent parameters
      # @return [Hash] The resource parameters
      def resource_params
        input_params = submitted_resource_params.dup

        override_entity_scoping_params(input_params)
        override_parent_params(input_params)

        current_presenter.defined_field_inputs_for(*permitted_attributes).collect_all(input_params)
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

      # Creates a resource presenter
      # @param [Class] resource_class The resource class
      # @param [ActiveRecord::Base] resource_record The resource record
      # @return [Object] The resource presenter
      def resource_presenter(resource_class, resource_record)
        presenter_class = "#{current_package}::#{resource_class}Presenter".constantize
        presenter_class.new resource_context, resource_record
      rescue NameError
        super(resource_class, resource_record)
      end

      # Creates a resource query object
      # @param [Class] resource_class The resource class
      # @param [ActionController::Parameters] params The request parameters
      # @return [Object] The resource query object
      def resource_query_object(resource_class, params)
        query_object_class = "#{current_package}::#{resource_class}QueryObject".constantize
        query_object_class.new resource_context, params
      rescue NameError
        super(resource_class, params)
      end

      # Applies submitted resource params if they have been passed
      def maybe_apply_submitted_resource_params!
        ensure_get_request
        resource_record.attributes = submitted_resource_params if params[resource_param_key].present?
      end

      # Returns the current parent based on path parameters
      # @return [ActiveRecord::Base, nil] The current parent
      def current_parent
        return unless parent_route_param.present?

        @current_parent ||= begin
          parent_route_key = parent_route_param.to_s.gsub(/_id$/, "").to_sym
          parent_class = current_engine.resource_register.route_key_lookup[parent_route_key]
          parent_scope = parent_class.from_path_param(params[parent_route_param])
          parent_scope = parent_scope.associated_with(current_scoped_entity) if scoped_to_entity?
          parent_scope.first!
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
        return unless current_parent.present?

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
          input_params[scoped_entity_param_key] = current_scoped_entity
          input_params[:"#{scoped_entity_param_key}_id"] = current_scoped_entity.id
        end
      end

      # Overrides parent parameters
      # @param [Hash] input_params The input parameters
      def override_parent_params(input_params)
        if current_parent.present?
          input_params[parent_input_param] = current_parent
          input_params[:"#{parent_input_param}_id"] = current_parent.id
        end
      end

      # Constructs resource URL arguments
      # @param [Array] args The URL arguments
      # @param [Hash] kwargs The keyword arguments
      # @return [Array] The URL arguments
      def resource_url_args_for(*args, **kwargs)
        kwargs[:parent] = current_parent unless kwargs.key?(:parent)
        super(*args, **kwargs)
      end
    end
  end
end

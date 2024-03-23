require "action_controller"
require "pagy"

require File.expand_path("refinements/parameter_refinements", Plutonium.lib_root)
using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Resource
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
        # we use class attribute since we want this value inherited
        class_attribute :resource_class, instance_writer: false, instance_predicate: false

        # https://github.com/ddnexus/pagy/blob/master/docs/extras/headers.md#headers
        after_action { pagy_headers_merge(@pagy) if @pagy }

        helper_method :current_parent, :resource_record, :resource_param_key, :resource_class
      end

      class_methods do
        def controller_for(resource_class)
          self.resource_class = resource_class
        end
      end

      private

      def policy_context
        Plutonium::Resource::PolicyContext.new(
          user: current_user,
          resource_context: resource_context
        )
      end

      def resource_record
        @resource_record ||= (policy_scope(resource_class).from_path_param(params[:id]).first! if params[:id].present?)
      end

      def submitted_resource_params
        @submitted_resource_params ||= begin
          strong_parameters = resource_class.strong_parameters_for(*permitted_attributes)
          params.require(resource_param_key).permit(*strong_parameters).nilify.to_h
        end
      end

      def resource_params
        input_params = submitted_resource_params.dup

        # Override any entity scoping params
        input_params[scoped_entity_param_key] = current_scoped_entity if scoped_to_entity?
        input_params[:"#{scoped_entity_param_key}_id"] = current_scoped_entity.id if scoped_to_entity?
        # Override any parent params
        input_params[parent_input_param] = current_parent if current_parent.present?
        input_params[:"#{parent_input_param}_id"] = current_parent.id if current_parent.present?

        # additionally filter our input_params through our inputs
        current_presenter.defined_inputs_for(*permitted_attributes).collect_all(input_params)
      end

      def resource_param_key
        resource_class.model_name.singular_route_key
      end

      def resource_context
        Plutonium::Resource::Context.new(
          resource_class:,
          parent: current_parent,
          scope: scoped_to_entity? ? current_scoped_entity : nil
        )
      end

      def resource_presenter(resource_class, resource_record)
        presenter_class = "#{current_package}::#{resource_class}Presenter".constantize
        presenter_class.new resource_context, resource_record
      end

      def resource_query_object(resource_class, params)
        query_object_class = "#{current_package}::#{resource_class}QueryObject".constantize
        query_object_class.new resource_context, params
      end

      # sets params on submitted_resource_params if they have been passed
      def maybe_apply_submitted_resource_params!
        # this is useful in dynamic forms as we can read the resource record to determine how to define our inputs
        # we need to ensure that this is being called from get because
        # it is potentially unsafe since we don't apply the input filter. see #resource_params
        # would have been nice to be able to, but we can't until we have the presenter, and the presenter
        # requires the resource_record for our dynamic forms
        # is this perfect? no. but it works.
        raise "🚨🚨🚨 this should be called from actions that are not persisting this data" unless request.method == "GET"

        resource_record.attributes = submitted_resource_params if params[resource_param_key].present?
      end

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

      def parent_input_param
        return unless current_parent.present?

        resource_class.reflect_on_all_associations(:belongs_to).find { |assoc| assoc.klass == current_parent.class }&.name&.to_sym
      end

      ############

      # def current_package
      #   @current_package ||= self.class.module_parents[-2]
      # end

      def resource_url_args_for(*args, **kwargs)
        kwargs[:parent] = current_parent unless kwargs.key?(:parent)
        super(*args, **kwargs)
      end
    end
  end
end

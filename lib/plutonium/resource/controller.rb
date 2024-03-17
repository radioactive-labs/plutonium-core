require "action_controller"
require "pagy"

require File.expand_path("refinements/parameter_refinements", Plutonium.lib_root)
using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Resource
    class Controller < ActionController::Base
      # remove this controller from the view lookup
      # has the side effect of marking all public methods as private.
      abstract!

      include Pagy::Backend
      include Plutonium::Core::Controllers::Authorizable
      include Plutonium::Core::Controllers::Presentable
      include Plutonium::Core::Controllers::Queryable

      def self.inherited(child)
        # Include our actions after we are inherited else they are marked as private due to our call to abstract!
        child.send :include, Plutonium::Core::Controllers::CrudActions
        child.send :include, Plutonium::Core::Controllers::InteractiveActions

        Plutonium::Core::Controllers::CrudActions.included_after_inheritance(child)
        Plutonium::Core::Controllers::InteractiveActions.included_after_inheritance(child)

        super
      end

      add_flash_types :success, :warning, :error
      append_view_path File.expand_path("app/views", Plutonium.root)

      # layout "resource"
      layout -> { turbo_frame_request? ? false : "resource" }
      helper Plutonium::Helpers

      before_action :set_page_title

      before_action do
        return unless defined?(ActiveStorage)

        ActiveStorage::Current.url_options = {protocol: request.protocol, host: request.host, port: request.port}
      end

      # https://github.com/ddnexus/pagy/blob/master/docs/extras/headers.md#headers
      after_action { pagy_headers_merge(@pagy) if @pagy }

      # Controller Resource

      # we use class attribute since we want this value inherited
      class_attribute :resource_class, instance_writer: false, instance_predicate: false
      helper_method :resource_class

      def self.controller_for(resource_class)
        self.resource_class = resource_class
      end

      private

      # def current_layout
      #   send :_layout, lookup_context, []
      # end

      # Resource

      def resource_record
        @resource_record ||= (policy_scope(resource_class).from_path_param(params[:id]).first! if params[:id].present?)
      end
      helper_method :resource_record

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
      helper_method :resource_param_key

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

      # Layout

      def set_page_title
        @page_title = "Pluton8"
      end

      def resource_context
        Plutonium::Resource::Context.new(
          resource_class:,
          parent: current_parent,
          scope: scoped_to_entity? ? current_scoped_entity : nil
        )
      end

      ############

      def current_package
        @current_package ||= self.class.module_parents[-2]
      end
    end
  end
end

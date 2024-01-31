require "action_controller"
require "pagy"
require "ransack"

require File.expand_path("refinements/parameter_refinements", Plutonium.lib_root)
using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Reactor
    class ResourceController < ActionController::Base
      # remove this controller from the view lookup
      # has the side effect of marking all public methods as private.
      abstract!

      include Pagy::Backend
      include Plutonium::Core::Controllers::Bootable
      include Plutonium::Core::Controllers::Authorizable
      include Plutonium::Core::Controllers::Presentable

      def self.inherited(child)
        # Include our actions after we are inherited else they are marked as private due to our call to abstract!
        child.send :include, Plutonium::Core::Controllers::CrudActions
        super
      end

      add_flash_types :success, :warning, :error
      append_view_path File.expand_path("app/views", Plutonium.root)

      layout "resource"
      helper Plutonium::Helpers

      before_action :set_page_title
      before_action :set_sidebar_menu
      before_action :authorize_custom_action, only: %i[custom_action commit_custom_action]

      # https://github.com/ddnexus/pagy/blob/master/docs/extras/headers.md#headers
      after_action { pagy_headers_merge(@pagy) if @pagy }

      private

      # def current_layout
      #   send :_layout, lookup_context, []
      # end

      def custom_actions
        @custom_actions ||= current_presenter.actions.except :new, :show, :edit, :destroy
      end

      def authorize_custom_action
        custom_action = params[:custom_action]&.to_sym

        unless custom_actions.key?(custom_action)
          raise ::AbstractController::ActionNotFound, "Unknown action #{custom_action}'"
        end

        authorize resource_record, :"#{custom_action}?"
      end

      # Resource

      def resource_record
        @resource_record ||= (policy_scope(resource_class).from_path_param(params[:id]).first! if params[:id].present?)
      end
      helper_method :resource_record

      def resource_params
        input_params = params.require(resource_param_key).permit!.nilify.to_h
        current_presenter.inputs_for(current_permitted_attributes)
          .values.map { |input| input.collect input_params }
          .reduce(:merge)
      end

      def resource_param_key
        resource_class.model_name.singular_route_key
      end
      helper_method :resource_param_key

      # Layout

      def set_page_title
        @page_title = "Dashboard"
      end

      def set_sidebar_menu
        @sidebar_menu = build_sidebar_menu
      end

      def build_sidebar_menu
        raise NotImplementedError, "build_sidebar_menu"
      end

      def resource_context
        Plutonium::Reactor::ResourceContext.new(
          user: current_user,
          resource_class:,
          resource_record: @resource_record,
          parent: current_parent,
          scope: scoped_to_entity? ? current_scoped_entity : nil
        )
      end

      ############

      def current_package
        @current_package ||= self.class.module_parents[-2]
      end

      def current_user
        raise NotImplementedError, "current_user"
      end
    end
  end
end

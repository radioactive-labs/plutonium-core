require "action_controller"
require "pundit"
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
      include Pundit::Authorization
      include Plutonium::Core::Controllers::Bootable

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
      before_action :set_associations
      before_action :authorize_custom_action, only: %i[custom_action commit_custom_action]

      after_action :verify_authorized
      after_action :verify_policy_scoped, except: %i[new create]

      # https://github.com/ddnexus/pagy/blob/master/docs/extras/headers.md#headers
      after_action { pagy_headers_merge(@pagy) if @pagy }

      private

      # def current_layout
      #   send :_layout, lookup_context, []
      # end

      def custom_actions
        @custom_actions ||= current_presenter.build_actions.action_definitions.except :create, :show, :edit, :destroy
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
        # we don't care much about strong parameters since we have our own whitelist
        # strong params and pundit permitted_attributes don't support array/hash params without a convoluted
        # attribute list
        form_params = params.require(resource_param_key).permit!.nilify.to_h.with_indifferent_access
        form_params[parent_param_key] = current_parent.id if current_parent.present?

        # debugger

        form_params
      end

      def resource_param_key
        resource_class.model_name.singular_route_key
      end
      helper_method :resource_param_key

      # Presentation

      def current_presenter
        resource_presenter resource_class
      end

      def resource_presenter(resource_class)
        raise NotImplementedError, "resource_presenter"
      end

      def build_collection
        table = current_presenter.build_collection(permitted_attributes)
        table.except_fields!(parent_param_key.to_s.gsub(/_id$/, "").to_sym) if current_parent.present?

        table
      end

      def build_detail
        detail = current_presenter.build_detail(permitted_attributes)
        detail.except_fields!(parent_param_key.to_s.gsub(/_id$/, "").to_sym) if current_parent.present?

        detail
      end

      def build_form
        form = current_presenter.build_form(permitted_attributes)
        form.except_inputs!(parent_param_key) if current_parent.present?

        form
      end

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

      def set_associations
        @associations = if current_parent.present?
          resource_presenter(current_parent.class).build_associations(parent_policy.permitted_associations).with_record(current_parent)
        elsif action_name == "show"
          current_presenter.build_associations(current_policy.permitted_associations).with_record(resource_record)
        end
      end

      # Authorisation

      def permitted_attributes(policy_subject = nil)
        @permitted_attributes ||= current_policy.send :"permitted_attributes_for_#{action_name}"
      end
      helper_method :permitted_attributes

      def current_policy
        policy_subject = resource_record || resource_class
        policy(policy_subject)
      end

      def parent_policy
        return unless current_parent.present?

        policy(current_parent)
      end

      def policy(scope)
        super(policy_namespace(scope))
      end

      def policy_scope(scope)
        super(policy_namespace(scope))
      end

      def authorize(record, query = nil)
        super(policy_namespace(record), query)
      end

      def policy_namespace(scope)
        raise NotImplementedError, "policy_namespace"
      end

      def pundit_user
        resource_context
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

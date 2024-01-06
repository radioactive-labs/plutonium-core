# frozen_string_literal: true

require "action_controller"
require "pundit"
require "pagy"
require File.expand_path("lib/plutonium/refinements/parameter_refinements", Plutonium.root)

using Plutonium::Refinements::ParameterRefinements

module Plutonium
  module Core
    class ResourceController < ActionController::Base
      include Pagy::Backend
      include Pundit::Authorization

      add_flash_types :success, :warning, :error
      append_view_path File.expand_path("views", Plutonium.root)

      layout "resource"

      before_action :set_page_title
      before_action :set_sidebar_menu
      before_action :set_associations
      before_action :authorize_custom_action, only: %i[custom_action commit_custom_action]

      after_action :verify_authorized
      after_action :verify_policy_scoped, except: %i[new create]

      # https://github.com/ddnexus/pagy/blob/master/docs/extras/headers.md#headers
      after_action { pagy_headers_merge(@pagy) if @pagy }

      # GET /resources(.{format})
      def index
        authorize resource_class

        q = policy_scope(resource_class).ransack(params[:q])
        pagy, @resource_records = pagy q.result
        @table = build_collection
          .with_records(@resource_records)
          .with_pagination(pagy)
          .search_with(q, resource_search_field)

        render :index
      end

      # GET /resources/1(.{format})
      def show
        authorize resource_record

        @record = resource_record
        @detail = build_detail.with_record(@record)

        render :show
      end

      # GET /resources/new
      def new
        authorize resource_class

        @form = build_form.with_record(resource_class.new)

        render :new
      end

      # GET /resources/1/edit
      def edit
        authorize resource_record

        @form = build_form.with_record(resource_record)

        render :edit
      end

      # POST /resources(.{format})
      def create
        authorize resource_class

        respond_to do |format|
          @record = resource_class.new(resource_params)

          if @record.save
            format.html do
              redirect_to adapt_route_args(@record),
                notice: "#{helpers.resource_name(resource_class)} was successfully created."
            end
            format.any { render :show, status: :created, location: adapt_route_args(@record) }
          else
            format.html do
              @form = build_form.with_record(@record)
              render :new, status: :unprocessable_entity
            end
            format.any do
              @errors = @record.errors
              render "errors", status: :unprocessable_entity
            end
          end
        end
      end

      # PATCH/PUT /resources/1(.{format})
      def update
        authorize resource_record

        respond_to do |format|
          @record = resource_record

          if @record.update(resource_params)
            format.html do
              redirect_to adapt_route_args(@record), notice: "#{helpers.resource_name(resource_class)} was successfully updated.",
                status: :see_other
            end
            format.any { render :show, status: :ok, location: adapt_route_args(@record) }
          else
            format.html do
              @form = build_form.with_record(@record)
              render :edit, status: :unprocessable_entity
            end
            format.any do
              @errors = @record.errors
              render "errors", status: :unprocessable_entity
            end
          end
        end
      end

      # DELETE /resources/1(.{format})
      def destroy
        authorize resource_record

        respond_to do |format|
          resource_record.destroy

          format.html do
            redirect_to adapt_route_args(resource_class),
              notice: "#{helpers.resource_name(resource_class)} was successfully deleted."
          end
          format.json { head :no_content }
        rescue ActiveRecord::InvalidForeignKey => e
          format.html do
            redirect_to adapt_route_args(resource_record),
              alert: "#{helpers.resource_name(resource_class)} is referenced by other records."
          end
          format.any do
            @errors = ActiveModel::Errors.new resource_record
            @errors.add :base, :existing_references, message: "is referenced by other records"

            render "errors", status: :unprocessable_entity
          end
        end
      end

      # GET /resources/1/:custom_action
      def custom_action
        @action = custom_actions[params[:custom_action].to_sym]
        @interaction = @action.interaction.new resource: resource_record

        if helpers.current_turbo_frame == "modal"
          render layout: false
        else
          render
        end
      end

      # POST /resources/1/:custom_action(.{format})
      def commit_custom_action
        @action = custom_actions[params[:custom_action].to_sym]

        respond_to do |format|
          inputs = (params[:resource] || {}).merge(resource: resource_record)
          @interaction = @action.interaction.run(inputs)

          if @interaction.valid?
            flash[:notice] = "#{helpers.resource_name(resource_class)} was successfully updated."

            format.html { redirect_to adapt_route_args(@interaction.result), status: :see_other }
            format.any { render :show, status: :ok, location: adapt_route_args(@interaction.result) }

            if helpers.current_turbo_frame == "modal"
              format.turbo_stream do
                render turbo_stream: [
                  turbo_stream.redirect(url_for(adapt_route_args(@interaction.result)))
                ]
              end
            end
          else
            format.html do
              render :custom_action, status: :unprocessable_entity
            end
            format.any do
              @errors = @interaction.errors
              render "errors", status: :unprocessable_entity
            end

            if helpers.current_turbo_frame == "modal"
              format.turbo_stream do
                render turbo_stream: turbo_stream.replace(:modal, partial: "custom_action_form")
              end
            end
          end
        end
      end

      private

      def current_layout
        send :_layout, lookup_context, []
      end

      def custom_actions
        @custom_actions ||= current_presenter.build_actions.action_definitions.except :create, :show, :edit, :destroy
      end

      def authorize_custom_action
        custom_action = params[:custom_action]&.to_sym

        unless custom_actions.key?(custom_action)
          raise ::AbstractController::ActionNotFound, "Undefined action #{custom_action}'"
        end

        authorize resource_record, :"#{custom_action}?"
      end

      # Resource

      class << self
        attr_reader :resource_class, :resource_search_field

        def controller_for(resource_class, resource_search_field = nil)
          @resource_class = resource_class
          @resource_search_field = resource_search_field
        end
      end

      def resource_class
        self.class.resource_class
      end
      helper_method :resource_class

      def resource_search_field
        self.class.resource_search_field
      end

      def resource_record
        return unless params[:id].present?

        @resource_record ||= policy_scope(resource_class).from_path_param(params[:id]).first!
      end
      helper_method :resource_record

      def resource_params
        # we don't care much about strong parameters since we have our own whitelist
        # strong params and pundit permitted_attributes don't support array/hash params without a convoluted
        # attribute list
        form_params = params.require(resource_param_key).permit!.slice(*permitted_attributes)
        form_params[parent_param_key] = current_parent.id if current_parent.present?

        form_params.nilify
      end

      def resource_param_key
        resource_class.to_s.underscore.tr("/", "_")
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
        policy_subject ||= resource_record || resource_class
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
        [:resources, scope]
      end

      def pundit_user
        resource_context
      end

      def resource_context
        @resource_context ||= Pu::ResourceContext.new(
          resource_class:,
          user: current_user,
          parent: current_parent
        )
      end
    end
  end
end

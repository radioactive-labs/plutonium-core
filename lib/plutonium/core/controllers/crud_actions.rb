module Plutonium
  module Core
    module Controllers
      module CrudActions
        extend ActiveSupport::Concern

        included do
          helper_method :preferred_action_after_submit
        end

        # GET /resources(.{format})
        def index
          authorize resource_class
          set_page_title resource_class.model_name.human.pluralize.titleize

          @search_object = current_query_object
          base_query = policy_scope(resource_class)
          base_query = @search_object.apply(base_query)
          base_query = base_query.public_send(params[:scope].to_sym) if params[:scope].present?
          @pagy, @resource_records = pagy base_query
          @collection = build_collection

          render :index
        end

        # GET /resources/1(.{format})
        def show
          authorize resource_record
          set_page_title resource_record.to_label.titleize

          @detail = build_detail

          render :show
        end

        # GET /resources/new
        def new
          authorize resource_class
          set_page_title "Create #{resource_class.model_name.human.titleize}"

          @resource_record = resource_class.new
          maybe_apply_submitted_resource_params!
          @form = build_form

          render :new
        end

        # POST /resources(.{format})
        def create
          authorize resource_class
          set_page_title "Create #{resource_class.model_name.human.titleize}"

          @resource_record = resource_class.new resource_params

          respond_to do |format|
            if resource_record.save
              format.html do
                redirect_to redirect_url_after_submit,
                  notice: "#{resource_class.model_name.human} was successfully created."
              end
              format.any { render :show, status: :created, location: redirect_url_after_submit }
            else
              format.html do
                @form = build_form
                render :new, status: :unprocessable_entity
              end
              format.any do
                @errors = resource_record.errors
                render "errors", status: :unprocessable_entity
              end
            end
          end
        end

        # GET /resources/1/edit
        def edit
          authorize resource_record
          set_page_title "Update #{resource_record.to_label.titleize}"

          maybe_apply_submitted_resource_params!
          @form = build_form

          render :edit
        end

        # PATCH/PUT /resources/1(.{format})
        def update
          authorize resource_record
          set_page_title "Update #{resource_record.to_label.titleize}"

          respond_to do |format|
            if resource_record.update(resource_params)
              format.html do
                redirect_to redirect_url_after_submit, notice: "#{resource_class.model_name.human} was successfully updated.",
                  status: :see_other
              end
              format.any { render :show, status: :ok, location: redirect_url_after_submit }
            else
              format.html do
                @form = build_form
                render :edit, status: :unprocessable_entity
              end
              format.any do
                @errors = resource_record.errors
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
              redirect_to resource_url_for(resource_class),
                notice: "#{resource_class.model_name.human} was successfully deleted."
            end
            format.json { head :no_content }
          rescue ActiveRecord::InvalidForeignKey
            format.html do
              redirect_to resource_url_for(resource_record),
                alert: "#{resource_class.model_name.human} is referenced by other records."
            end
            format.any do
              @errors = ActiveModel::Errors.new resource_record
              @errors.add :base, :existing_references, message: "is referenced by other records"

              render "errors", status: :unprocessable_entity
            end
          end
        end

        private

        def redirect_url_after_submit
          url = case preferred_action_after_submit
          when "show"
            resource_url_for(resource_record) if current_policy.show?
          when "edit"
            resource_url_for(resource_record, action: :edit) if current_policy.edit?
          when "new"
            resource_url_for(resource_class, action: :new) if current_policy.new?
          when "index"
            resource_url_for(resource_class) if current_policy.index?
          else
            # ensure we have a valid value
            session[:action_after_submit_preference] = "show"
          end
          url || resource_url_for(resource_record)
        end

        def preferred_action_after_submit
          @preferred_action_after_submit = begin
            if %w[new edit show index].include? params[:commit]
              session[:action_after_submit_preference] = params[:commit]
            end
            session[:action_after_submit_preference] || "show"
          end
        end
      end
    end
  end
end

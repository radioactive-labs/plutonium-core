module Plutonium
  module Resource
    module Controllers
      module CrudActions
        extend ActiveSupport::Concern
        include IndexAction

        included do
          helper_method :preferred_action_after_submit
        end

        # GET /resources(.{format})
        def index
          authorize_current! resource_class
          set_page_title resource_class.model_name.human.pluralize.titleize

          setup_index_action!

          respond_to do |format|
            format.any(:html, :turbo_stream) { render :index, formats: [:html] }
            format.any { render :index }
          end
        end

        # GET /resources/1(.{format})
        def show
          authorize_current! resource_record!
          set_page_title resource_record!.to_label.titleize

          respond_to do |format|
            format.any(:html, :turbo_stream) { render :show, formats: [:html] }
            format.any { render :show }
          end
        end

        # GET /resources/new
        def new
          authorize_current! resource_class
          set_page_title "Create #{resource_class.model_name.human.titleize}"

          @resource_record = resource_class.new
          maybe_apply_submitted_resource_params!

          render :new, formats: [:html]
        end

        # POST /resources(.{format})
        def create
          authorize_current! resource_class
          set_page_title "Create #{resource_class.model_name.human.titleize}"

          @resource_record = resource_class.new resource_params

          respond_to do |format|
            if params[:pre_submit]
              format.turbo_stream { render turbo_stream: turbo_stream.replace("resource-form", view_context.render(build_form(action: :new))) }
              format.html { render :new, status: :unprocessable_content }
            elsif resource_record!.save
              format.turbo_stream do
                flash.notice = "#{resource_class.model_name.human} was successfully created."
                render turbo_stream: helpers.turbo_stream_redirect(redirect_url_after_submit)
              end
              format.html do
                redirect_to redirect_url_after_submit,
                  notice: "#{resource_class.model_name.human} was successfully created."
              end
              format.any do
                @current_policy = nil # Reset cached policy so it uses the instance instead of class
                render :show,
                  status: :created,
                  location: redirect_url_after_submit
              end
            else
              format.turbo_stream { render turbo_stream: turbo_stream.replace("resource-form", view_context.render(build_form(action: :new))), status: :unprocessable_content }
              format.html { render :new, status: :unprocessable_content }
              format.any do
                @errors = resource_record!.errors
                render "errors", status: :unprocessable_content
              end
            end
          end
        end

        # GET /resources/1/edit
        def edit
          authorize_current! resource_record!
          set_page_title "Update #{resource_record!.to_label.titleize}"

          maybe_apply_submitted_resource_params!

          render :edit, formats: [:html]
        end

        # PATCH/PUT /resources/1(.{format})
        def update
          authorize_current! resource_record!
          set_page_title "Update #{resource_record!.to_label.titleize}"

          resource_record!.attributes = resource_params

          respond_to do |format|
            if params[:pre_submit]
              format.turbo_stream { render turbo_stream: turbo_stream.replace("resource-form", view_context.render(build_form(action: :edit))) }
              format.html { render :edit, status: :unprocessable_content }
            elsif resource_record!.save
              format.turbo_stream do
                flash.notice = "#{resource_class.model_name.human} was successfully updated."
                render turbo_stream: helpers.turbo_stream_redirect(redirect_url_after_submit)
              end
              format.html do
                redirect_to redirect_url_after_submit,
                  notice: "#{resource_class.model_name.human} was successfully updated.",
                  status: :see_other
              end
              format.any do
                render :show, status: :ok, location: redirect_url_after_submit
              end
            else
              format.turbo_stream { render turbo_stream: turbo_stream.replace("resource-form", view_context.render(build_form(action: :edit))), status: :unprocessable_content }
              format.html { render :edit, status: :unprocessable_content }
              format.any do
                @errors = resource_record!.errors
                render "errors", status: :unprocessable_content
              end
            end
          end
        end

        # DELETE /resources/1(.{format})
        def destroy
          authorize_current! resource_record!

          respond_to do |format|
            resource_record!.destroy

            format.turbo_stream do
              flash.notice = "#{resource_class.model_name.human} was successfully deleted."
              render turbo_stream: helpers.turbo_stream_redirect(redirect_url_after_destroy)
            end
            format.html do
              redirect_to redirect_url_after_destroy,
                notice: "#{resource_class.model_name.human} was successfully deleted."
            end
            format.json { head :no_content }
          rescue ActiveRecord::InvalidForeignKey
            format.turbo_stream do
              flash.alert = "#{resource_class.model_name.human} is referenced by other records."
              render turbo_stream: helpers.turbo_stream_redirect(resource_url_for(resource_record!))
            end
            format.html do
              redirect_to resource_url_for(resource_record!),
                alert: "#{resource_class.model_name.human} is referenced by other records."
            end
            format.any do
              @errors = ActiveModel::Errors.new resource_record!
              @errors.add :base,
                :existing_references,
                message: "is referenced by other records"

              render "errors", status: :unprocessable_content
            end
          end
        end

        private

        def redirect_url_after_submit
          if (return_to = url_from(params[:return_to]))
            return return_to
          end

          url = case preferred_action_after_submit
          when "show"
            resource_url_for(resource_record!) if resource_record? && current_policy.allowed_to?(:show?, resource_record!)
          when "edit"
            resource_url_for(resource_record!, action: :edit) if resource_record? && current_policy.allowed_to?(:edit?, resource_record!)
          when "new"
            resource_url_for(resource_class, action: :new) if current_policy.allowed_to?(:new?, resource_class)
          when "index"
            resource_url_for(resource_class) if current_policy.allowed_to?(:index?, resource_class)
          else
            # ensure we have a valid value
            session[:action_after_submit_preference] = "show"
          end
          url || resource_url_for(resource_record!)
        end

        def redirect_url_after_destroy
          if (return_to = url_from(params[:return_to])) && return_to != request.url
            return return_to
          end

          resource_url_for(resource_class)
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

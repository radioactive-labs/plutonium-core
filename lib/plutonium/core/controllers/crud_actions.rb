module Plutonium
  module Core
    module Controllers
      module CrudActions
        extend ActiveSupport::Concern

        # GET /resources(.{format})
        def index
          authorize resource_class

          @ransack = policy_scope(resource_class).ransack(params[:q])
          @pagy, @resource_records = pagy @ransack.result
          @collection = build_collection

          render :index
        end

        # GET /resources/1(.{format})
        def show
          authorize resource_record

          @detail = build_detail

          render :show
        end

        # GET /resources/new
        def new
          authorize resource_class

          @resource_record = resource_class.new
          # set params if they have been passed
          resource_record.attributes = params[resource_param_key].present? ? resource_params : {}
          @form = build_form

          render :new
        end

        # POST /resources(.{format})
        def create
          authorize resource_class

          @resource_record = resource_class.new resource_params

          respond_to do |format|
            if resource_record.save
              format.html do
                redirect_to adapt_route_args(resource_record),
                  notice: "#{resource_class.model_name.human} was successfully created."
              end
              format.any { render :show, status: :created, location: adapt_route_args(resource_record) }
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

          # set params if they have been passed
          resource_record.attributes = params[resource_param_key].present? ? resource_params : {}
          @form = build_form

          render :edit
        end

        # PATCH/PUT /resources/1(.{format})
        def update
          authorize resource_record

          respond_to do |format|
            if resource_record.update(resource_params)
              format.html do
                redirect_to adapt_route_args(resource_record), notice: "#{resource_class.model_name.human} was successfully updated.",
                  status: :see_other
              end
              format.any { render :show, status: :ok, location: adapt_route_args(resource_record) }
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
              redirect_to adapt_route_args(resource_class),
                notice: "#{resource_class.model_name.human} was successfully deleted."
            end
            format.json { head :no_content }
          rescue ActiveRecord::InvalidForeignKey
            format.html do
              redirect_to adapt_route_args(resource_record),
                alert: "#{resource_class.model_name.human} is referenced by other records."
            end
            format.any do
              @errors = ActiveModel::Errors.new resource_record
              @errors.add :base, :existing_references, message: "is referenced by other records"

              render "errors", status: :unprocessable_entity
            end
          end
        end
      end
    end
  end
end

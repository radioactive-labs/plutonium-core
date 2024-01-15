module Plutonium
  module Core
    module Controller
      module Actions
        extend ActiveSupport::Concern

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
      end
    end
  end
end

module Plutonium
  module Core
    module Controllers
      module InteractiveActions
        extend ActiveSupport::Concern

        included do
          before_action :authorize_interactive_resource_action, only: %i[begin_interactive_resource_action commit_interactive_resource_action]
          before_action :authorize_interactive_bulk_resource_action, only: %i[begin_interactive_bulk_resource_action commit_interactive_bulk_resource_action]
        end

        # GET /resources/1/actions/:interactive_action
        def begin_interactive_resource_action
          @action = interactive_resource_actions[params[:interactive_action].to_sym]
          @interaction = @action.interaction.new resource: resource_record

          if helpers.current_turbo_frame == "modal"
            render layout: false
          else
            render :interactive_resource_action
          end
        end

        # POST /resources/1/actions/:interactive_action
        def commit_interactive_resource_action
          @action = interactive_resource_actions[params[:interactive_action].to_sym]

          respond_to do |format|
            inputs = (params[:resource] || {}).merge(resource: resource_record)
            @interaction = @action.interaction.run(inputs)

            if @interaction.valid?
              flash[:notice] = "#{resource_class.model_name.human} was successfully updated."

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
                render :interactive_resource_action, status: :unprocessable_entity
              end
              format.any do
                @errors = @interaction.errors
                render "errors", status: :unprocessable_entity
              end

              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: turbo_stream.replace(:modal, partial: "interactive_resource_action_form")
                end
              end
            end
          end
        end

        # GET /resources/actions/:interactive_action
        def begin_interactive_bulk_resource_action
          policy_scope(resource_class).all

          @action = interactive_resource_actions[params[:interactive_action].to_sym]
          @interaction = @action.interaction.new resource: resource_record

          if helpers.current_turbo_frame == "modal"
            render layout: false
          else
            render :interactive_bulk_resource_action
          end
        end

        # POST /resources/actions/:interactive_action
        def commit_interactive_bulk_resource_action
          @action = interactive_resource_actions[params[:interactive_action].to_sym]

          respond_to do |format|
            inputs = (params[:resource] || {}).merge(resource: resource_record)
            @interaction = @action.interaction.run(inputs)

            if @interaction.valid?
              flash[:notice] = "#{resource_class.model_name.human} was successfully updated."

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
                render :interactive_bulk_resource_action, status: :unprocessable_entity
              end
              format.any do
                @errors = @interaction.errors
                render "errors", status: :unprocessable_entity
              end

              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: turbo_stream.replace(:modal, partial: "interactive_bulk_resource_action_form")
                end
              end
            end
          end
        end

        private

        def interactive_resource_actions
          @interactive_resource_actions ||= current_presenter.actions.except :new, :show, :edit, :destroy
        end

        def authorize_interactive_resource_action
          interactive_resource_action = params[:interactive_action]&.to_sym

          unless interactive_resource_actions.key?(interactive_resource_action)
            raise ::AbstractController::ActionNotFound, "Unknown action #{interactive_resource_action}'"
          end

          authorize resource_record, :"#{interactive_resource_action}?"
        end

        def authorize_interactive_bulk_resource_action
          interactive_resource_action = params[:interactive_action]&.to_sym

          unless interactive_resource_actions.key?(interactive_resource_action)
            raise ::AbstractController::ActionNotFound, "Unknown action #{interactive_resource_action}'"
          end

          authorize resource_class, :"#{interactive_resource_action}?"
        end
      end
    end
  end
end

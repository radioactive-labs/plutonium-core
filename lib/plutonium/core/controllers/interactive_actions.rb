module Plutonium
  module Core
    module Controllers
      module InteractiveActions
        extend ActiveSupport::Concern

        included do
          helper_method :current_interactive_action

          before_action :validate_interactive_resource_action, only: %i[
            begin_interactive_resource_record_action commit_interactive_resource_record_action
            begin_interactive_resource_collection_action commit_interactive_resource_collection_action
            begin_interactive_resource_recordless_action commit_interactive_resource_recordless_action
          ]

          before_action :authorize_interactive_resource_record_action, only: %i[
            begin_interactive_resource_record_action commit_interactive_resource_record_action
          ]

          before_action :authorize_interactive_resource_action, only: %i[
            begin_interactive_resource_collection_action commit_interactive_resource_collection_action
            begin_interactive_resource_recordless_action commit_interactive_resource_recordless_action
          ]
        end

        # GET /resources/1/actions/:interactive_action
        def begin_interactive_resource_record_action
          @interaction = current_interactive_action.interaction.new interaction_params

          if helpers.current_turbo_frame == "modal"
            render layout: false
          else
            render :interactive_resource_record_action
          end
        end

        # POST /resources/1/actions/:interactive_action
        def commit_interactive_resource_record_action
          respond_to do |format|
            inputs = interaction_params.merge(resource: resource_record)
            @interaction = current_interactive_action.interaction.run(inputs)

            if @interaction.valid?
              flash[:notice] = "TODO:#{current_interactive_action} was successfully updated."

              format.html { redirect_to resource_url_for(@interaction.result), status: :see_other }
              format.any { render :show, status: :ok, location: resource_url_for(@interaction.result) }

              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: [
                    turbo_stream.redirect(resource_url_for(@interaction.result))
                  ]
                end
              end
            else
              format.html do
                render :interactive_resource_record_action, status: :unprocessable_entity
              end
              format.any do
                @errors = @interaction.errors
                render "errors", status: :unprocessable_entity
              end

              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: turbo_stream.replace(:modal, partial: "interactive_resource_record_action_form")
                end
              end
            end
          end
        end

        # GET /resources/actions/:interactive_action?ids[]=1&ids[]=2
        def begin_interactive_resource_collection_action
          # TODO: ensure that the selected list matches the returned value
          interactive_resource_collection
          @interaction = current_interactive_action.interaction.new((params[:interaction] || {}).except(:resources))

          if helpers.current_turbo_frame == "modal"
            render layout: false
          else
            render :interactive_resource_collection_action
          end
        end

        # POST /resources/actions/:interactive_action?ids[]=1&ids[]=2
        def commit_interactive_resource_collection_action
          respond_to do |format|
            inputs = interaction_params.merge(resources: interactive_resource_collection)
            @interaction = current_interactive_action.interaction.run(inputs)

            if @interaction.valid?
              collection_count = interactive_resource_collection.size

              flash[:notice] = "TODO:#{current_interactive_action} #{collection_count} #{resource_class.model_name.human.pluralize(collection_count)} successfully updated."

              format.html { redirect_to resource_url_for(resource_class) }
              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: [
                    turbo_stream.redirect(resource_url_for(resource_class))
                  ]
                end
              end
            else
              format.html do
                render :interactive_resource_collection_action, status: :unprocessable_entity
              end
              format.any do
                @errors = @interaction.errors
                render "errors", status: :unprocessable_entity
              end

              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: turbo_stream.replace(:modal, partial: "interactive_resource_collection_action_form")
                end
              end
            end
          end
        end

        # GET /resources/actions/:interactive_action
        def begin_interactive_resource_recordless_action
          skip_policy_scope

          @interaction = current_interactive_action.interaction.new interaction_params

          if helpers.current_turbo_frame == "modal"
            render layout: false
          else
            render :interactive_resource_recordless_action
          end
        end

        # POST /resources/actions/:interactive_action
        def commit_interactive_resource_recordless_action
          skip_policy_scope

          respond_to do |format|
            inputs = interaction_params
            @interaction = current_interactive_action.interaction.run(inputs)

            if @interaction.valid?
              flash[:notice] = "TODO:#{current_interactive_action} was successfully updated."

              format.html { redirect_to resource_url_for(resource_class) }

              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: [
                    turbo_stream.redirect(resource_url_for(resource_class))
                  ]
                end
              end
            else
              format.html do
                render :interactive_resource_recordless_action, status: :unprocessable_entity
              end
              format.any do
                @errors = @interaction.errors
                render "errors", status: :unprocessable_entity
              end

              if helpers.current_turbo_frame == "modal"
                format.turbo_stream do
                  render turbo_stream: turbo_stream.replace(:modal, partial: "interactive_resource_recordless_action_form")
                end
              end
            end
          end
        end

        private

        def current_interactive_action
          @current_interactive_action = interactive_resource_actions[params[:interactive_action].to_sym]
        end

        def interactive_resource_actions
          @interactive_resource_actions ||= current_presenter.actions.except :new, :show, :edit, :destroy
        end

        def validate_interactive_resource_action
          interactive_resource_action = params[:interactive_action]&.to_sym
          unless interactive_resource_actions.key?(interactive_resource_action)
            raise ::AbstractController::ActionNotFound, "Unknown action '#{interactive_resource_action}'"
          end
        end

        def authorize_interactive_resource_record_action
          interactive_resource_action = params[:interactive_action]&.to_sym
          authorize resource_record, :"#{interactive_resource_action}?"
        end

        def authorize_interactive_resource_action
          interactive_resource_action = params[:interactive_action]&.to_sym
          authorize resource_class, :"#{interactive_resource_action}?"
        end

        def interactive_resource_collection
          @interactive_resource_collection ||= policy_scope(resource_class).from_path_param(params.require(:ids)).all
        end

        def interaction_params
          # active interaction handles filtering so no need for strong params
          (params[:interaction] || {}).except(:resource, :resources)
        end
      end
    end
  end
end

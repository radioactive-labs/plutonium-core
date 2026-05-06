module Plutonium
  module Resource
    module Controllers
      module InteractiveActions
        extend ActiveSupport::Concern

        included do
          helper_method :current_interactive_action

          before_action :validate_interactive_action!, only: %i[
            interactive_record_action commit_interactive_record_action
            interactive_bulk_action commit_interactive_bulk_action
            interactive_resource_action commit_interactive_resource_action
          ]

          before_action :authorize_interactive_record_action!, only: %i[
            interactive_record_action commit_interactive_record_action
          ]

          before_action :authorize_interactive_resource_action!, only: %i[
            interactive_resource_action commit_interactive_resource_action
          ]

          before_action :authorize_interactive_bulk_action!, only: %i[
            interactive_bulk_action commit_interactive_bulk_action
          ]
        end

        # GET /resources/1/record_actions/:interactive_action
        def interactive_record_action
          build_interactive_record_action_interaction
          render :interactive_record_action, formats: [:html], **modal_render_options
        end

        # POST /resources/1/record_actions/:interactive_action
        def commit_interactive_record_action
          build_interactive_record_action_interaction

          if params[:pre_submit]
            respond_to do |format|
              format.turbo_stream { render turbo_stream: turbo_stream.replace("interaction-form", view_context.render(@interaction.build_form)) }
              format.html { render :interactive_record_action, formats: [:html], status: :unprocessable_content }
            end
            return
          end

          outcome = @interaction.call

          outcome.to_response.process(self) do |value|
            respond_to do |format|
              if outcome.success?
                return_url = redirect_url_after_action_on(resource_record!)

                format.turbo_stream do
                  render turbo_stream: helpers.turbo_stream_redirect(return_url)
                end
                format.html do
                  redirect_to return_url, status: :see_other
                end
                format.any do
                  render :show, status: :ok, location: return_url
                end
              else
                format.any(:html, :turbo_stream) do
                  render :interactive_record_action, formats: [:html], content_type: "text/html", **modal_render_options, status: :unprocessable_content
                end
                format.any do
                  @errors = @interaction.errors
                  render "errors", status: :unprocessable_content
                end
              end
            end
          end
        end

        # GET /resources/resource_actions/:interactive_action
        def interactive_resource_action
          skip_verify_current_authorized_scope!
          build_interactive_resource_action_interaction
          render :interactive_resource_action, formats: [:html], **modal_render_options
        end

        # POST /resources/resource_actions/:interactive_action
        def commit_interactive_resource_action
          skip_verify_current_authorized_scope!
          build_interactive_resource_action_interaction

          if params[:pre_submit]
            respond_to do |format|
              format.turbo_stream { render turbo_stream: turbo_stream.replace("interaction-form", view_context.render(@interaction.build_form)) }
              format.html { render :interactive_resource_action, status: :unprocessable_content }
            end
            return
          end

          outcome = @interaction.call

          outcome.to_response.process(self) do |value|
            respond_to do |format|
              if outcome.success?
                return_url = redirect_url_after_action_on(resource_class)

                format.turbo_stream do
                  render turbo_stream: helpers.turbo_stream_redirect(return_url)
                end
                format.html do
                  redirect_to return_url, status: :see_other
                end
                format.any do
                  head :no_content, location: return_url
                end
              else
                format.any(:html, :turbo_stream) do
                  render :interactive_resource_action, formats: [:html], content_type: "text/html", **modal_render_options, status: :unprocessable_content
                end
                format.any do
                  @errors = @interaction.errors
                  render "errors", status: :unprocessable_content
                end
              end
            end
          end
        end

        # GET /resources/bulk_actions/:interactive_action?ids[]=1&ids[]=2
        def interactive_bulk_action
          build_interactive_bulk_action_interaction
          render :interactive_bulk_action, formats: [:html], **modal_render_options
        end

        # POST /resources/bulk_actions/:interactive_action?ids[]=1&ids[]=2
        def commit_interactive_bulk_action
          build_interactive_bulk_action_interaction

          if params[:pre_submit]
            respond_to do |format|
              format.turbo_stream { render turbo_stream: turbo_stream.replace("interaction-form", view_context.render(@interaction.build_form)) }
              format.html { render :interactive_bulk_action, formats: [:html], status: :unprocessable_content }
            end
            return
          end

          outcome = @interaction.call

          outcome.to_response.process(self) do |value|
            respond_to do |format|
              if outcome.success?
                return_url = redirect_url_after_action_on(resource_class)

                format.turbo_stream do
                  render turbo_stream: helpers.turbo_stream_redirect(return_url)
                end
                format.html do
                  redirect_to return_url, status: :see_other
                end
                format.any do
                  head :no_content, location: return_url
                end
              else
                format.any(:html, :turbo_stream) do
                  render :interactive_bulk_action, formats: [:html], content_type: "text/html", **modal_render_options, status: :unprocessable_content
                end
                format.any do
                  @errors = @interaction.errors
                  render "errors", status: :unprocessable_content
                end
              end
            end
          end
        end

        private

        # Render options for modal-aware actions. Returns `{ layout: false }` for
        # turbo-frame requests so the bare frame is rendered, and an empty hash
        # for top-level requests so the controller's default layout proc applies.
        # (Passing `layout: nil` explicitly is treated as "no layout" by Rails,
        # which is why we omit the key entirely on the default path.)
        def modal_render_options
          helpers.current_turbo_frame.present? ? {layout: false} : {}
        end

        def current_interactive_action
          @current_interactive_action = interactive_resource_actions[params[:interactive_action].to_sym]
        end

        def interactive_resource_actions
          @interactive_resource_actions ||= current_definition
            .defined_actions
            .select { |k, v| v.is_a?(Plutonium::Action::Interactive) }
        end

        def validate_interactive_action!
          interactive_resource_action = params[:interactive_action]&.to_sym
          unless interactive_resource_actions.key?(interactive_resource_action)
            raise ::AbstractController::ActionNotFound, "Unknown action '#{interactive_resource_action}'"
          end
        end

        def authorize_interactive_record_action!
          interactive_resource_action = params[:interactive_action]&.to_sym
          authorize_current! resource_record!, to: :"#{interactive_resource_action}?"
        end

        def authorize_interactive_resource_action!
          interactive_resource_action = params[:interactive_action]&.to_sym
          authorize_current! resource_class, to: :"#{interactive_resource_action}?"
        end

        def authorize_interactive_bulk_action!
          action_name = params[:interactive_action]&.to_sym
          policy_method = :"#{action_name}?"

          # Authorize each record individually - fail if any record is not authorized
          interactive_bulk.each do |record|
            authorize_current! record, to: policy_method
          end
        end

        def interactive_bulk
          @interactive_bulk ||= current_authorized_scope.from_path_param(params.require(:ids))
        end

        def build_interactive_record_action_interaction
          @interaction = current_interactive_action.interaction.new(view_context:)
          @interaction.attributes = interaction_params.merge(resource: resource_record!)
          @interaction
        end

        def build_interactive_resource_action_interaction
          @interaction = current_interactive_action.interaction.new(view_context:)
          @interaction.attributes = interaction_params
          @interaction
        end

        def build_interactive_bulk_action_interaction
          @interaction = current_interactive_action.interaction.new(view_context:)
          @interaction.attributes = interaction_params.merge(resources: interactive_bulk)
          @interaction
        end

        # Returns the submitted resource parameters
        # @return [Hash] The submitted resource parameters
        def submitted_interaction_params
          @submitted_interaction_params ||= current_interactive_action
            .interaction
            .build_form(current_interactive_action.interaction.new(view_context:))
            .extract_input(params, view_context:)[:interaction]
        end

        def redirect_url_after_action_on(resource_record_or_resource_class)
          if (return_to = url_from(params[:return_to]))
            return return_to
          end

          resource_url_for(resource_record_or_resource_class)
        end

        # Returns the resource parameters, including scoped and parent parameters
        # @return [Hash] The resource parameters
        def interaction_params
          @interaction_params ||= submitted_interaction_params.except(:resource, :resources)
        end
      end
    end
  end
end

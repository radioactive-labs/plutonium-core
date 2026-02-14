module Plutonium
  module Interaction
    module Response
      # Represents a render response.
      #
      # This class is used to render views as a result of an interaction.
      class Render < Base
        private

        # Executes the render response.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @return [void]
        def execute(controller)
          render_args = @args
          render_options = @options

          controller.instance_eval do
            respond_to do |format|
              format.turbo_stream do
                # For Turbo requests, replace the form with the rendered content
                render turbo_stream: turbo_stream.replace(
                  "interaction-form",
                  view_context.render(*render_args, **render_options)
                )
              end

              format.any { render(*render_args, **render_options) }
            end
          end
        end
      end
    end
  end
end

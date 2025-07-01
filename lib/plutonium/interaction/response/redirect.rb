module Plutonium
  module Interaction
    module Response
      # Represents a redirect response.
      #
      # This class is used to perform redirects as a result of an interaction.
      class Redirect < Base
        private

        # Executes the redirect response.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @return [void]
        def execute(controller)
          controller.instance_eval do
            url = url_for(*@args)

            format.any { redirect_to(url, **@options) }
            if helpers.current_turbo_frame == "remote_modal"
              format.turbo_stream do
                render turbo_stream: [
                  helpers.turbo_stream_redirect(url)
                ]
              end
            end
          end
        end
      end
    end
  end
end

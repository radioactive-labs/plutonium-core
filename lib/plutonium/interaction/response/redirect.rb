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
          # Capture the instance variables before entering instance_eval
          redirect_args = @args
          redirect_options = @options

          controller.instance_eval do
            url = url_for(*redirect_args)

            respond_to do |format|
              format.turbo_stream do
                if helpers.current_turbo_frame == "remote_modal"
                  render turbo_stream: [
                    helpers.turbo_stream_redirect(url)
                  ]
                else
                  redirect_to(url, **redirect_options)
                end
              end

              format.any { redirect_to(url, **redirect_options) }
            end
          end
        end
      end
    end
  end
end

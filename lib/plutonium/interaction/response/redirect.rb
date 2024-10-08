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
          controller.redirect_to(*@args, **@options)
        end
      end
    end
  end
end

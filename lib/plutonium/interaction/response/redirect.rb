module Plutonium
  module Interaction
    module Response
      # Represents a redirect response.
      #
      # This class is used to perform redirects as a result of an interaction.
      class Redirect < Base
        # Initializes a new Redirect response.
        #
        # @param path [String, Symbol] The path or named route to redirect to.
        # @param options [Hash] Additional options to pass to the redirect_to method.
        def initialize(path, options = {})
          super()
          @path = path
          @options = options
        end

        private

        # Executes the redirect response.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @return [void]
        def execute(controller)
          controller.redirect_to @path, @options
        end
      end
    end
  end
end

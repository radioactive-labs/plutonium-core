module Plutonium
  module Interaction
    module Response
      # Represents a render response.
      #
      # This class is used to render views as a result of an interaction.
      class Render < Base
        # Initializes a new Render response.
        #
        # @param options [Hash] Options to pass to the render method.
        def initialize(options = {})
          super()
          @options = options
        end

        private

        # Executes the render response.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @return [void]
        def execute(controller)
          controller.render @options
        end
      end
    end
  end
end

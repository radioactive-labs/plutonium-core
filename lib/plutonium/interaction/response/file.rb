module Plutonium
  module Interaction
    module Response
      # Represents a render response.
      #
      # This class is used to render views as a result of an interaction.
      class File < Base
        private

        # Executes the render response.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @return [void]
        def execute(controller)
          controller.send_file(*@args, @options)
        end
      end
    end
  end
end
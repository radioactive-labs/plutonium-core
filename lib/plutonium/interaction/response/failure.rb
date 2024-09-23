module Plutonium
  module Interaction
    module Response
      # Represents a failed response, which doesn't perform any specific action.
      class Failure < Base
        private

        # Executes the failure response by yielding.
        #
        # @param controller [ActionController::Base] The controller instance (unused).
        # @return [void]
        def execute(controller, &)
          yield
        end
      end
    end
  end
end

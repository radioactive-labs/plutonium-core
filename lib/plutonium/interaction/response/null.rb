module Plutonium
  module Interaction
    module Response
      # Represents a null response, which doesn't perform any specific action.
      #
      # This class is used when an interaction doesn't produce a specific response
      # type but still needs to wrap a result value.
      class Null < Base
        # @return [Object] The result value wrapped by this null response.
        attr_reader :result

        # Initializes a new Null response.
        #
        # @param result [Object] The result value to be wrapped.
        def initialize(result)
          super()
          @result = result
        end

        private

        # Executes the null response by yielding the result value.
        #
        # @param controller [ActionController::Base] The controller instance (unused).
        # @yield [Object] The result value wrapped by this response.
        # @return [void]
        def execute(controller, &)
          yield @result
        end
      end
    end
  end
end

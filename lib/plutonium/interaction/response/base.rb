module Plutonium
  module Interaction
    module Response
      # Base class for interaction responses.
      #
      # This class provides common functionality for handling flash messages
      # and processing responses in controllers.
      #
      # @abstract Subclass and override {#execute} to implement
      #   specific response behavior.
      class Base
        # @return [Array<Array(String, Symbol)>] Flash messages associated with the response.
        attr_reader :flash

        # Initializes a new Response::Base instance.
        def initialize(*args, **options)
          @args = args
          @options = options
          @flash = []
        end

        # Processes the response in the context of a controller.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @yield [Object] Executed if the response doesn't handle its own rendering.
        # @return [void]
        def process(controller, &)
          set_flash(controller)
          execute(controller, &)
        end

        # Adds flash messages to the response.
        #
        # @param messages [Array<Array(String, Symbol)>] The messages to add.
        # @return [self]
        def with_flash(messages)
          @flash.concat(messages) unless messages.blank?
          self
        end

        private

        # Sets flash messages in the controller.
        #
        # @param controller [ActionController::Base] The controller instance.
        # @return [void]
        def set_flash(controller)
          @flash.each do |message, type|
            controller.flash[type] = message
          end
        end

        # Executes the response logic.
        #
        # @abstract
        # @param controller [ActionController::Base] The controller instance.
        # @yield [Object] Executed if the response doesn't handle its own rendering.
        # @raise [NotImplementedError] if not implemented in subclass.
        def execute(controller, &)
          raise NotImplementedError, "#{self.class} must implement #execute"
        end
      end
    end
  end
end

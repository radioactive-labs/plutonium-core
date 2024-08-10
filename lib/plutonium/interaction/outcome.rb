module Plutonium
  module Interaction
    # Base class for interaction outcomes.
    #
    # This class provides a common interface for both successful and failed outcomes
    # of an interaction.
    #
    # @abstract Subclass and override {#and_then}, {#map}, and {#to_response} to implement
    class Outcome
      # @return [Array<Array(String, Symbol)>] Messages associated with the outcome.
      attr_reader :messages

      # Checks if the outcome is successful.
      #
      # @return [Boolean] true if the outcome is a Success, false otherwise.
      def success?
        is_a?(Success)
      end

      # Checks if the outcome is a failure.
      #
      # @return [Boolean] true if the outcome is a Failure, false otherwise.
      def failure?
        is_a?(Failure)
      end

      # Adds a message to the outcome.
      #
      # @param msg [String] The message to add.
      # @param type [Symbol] The type of the message (e.g., :notice, :error).
      # @return [self]
      def with_message(msg, type = :notice)
        @messages ||= []
        @messages << [msg, type]
        self
      end

      # Sets the response for the outcome.
      #
      # @param response [Plutonium::Interaction::Response::Base] The response to set.
      #
      # @abstract
      # @raise [NotImplementedError] if not implemented in subclass.
      def with_response(response)
        raise NotImplementedError, "#{self.class} must implement #with_response"
      end

      # Chains another operation to be executed if this outcome is successful.
      #
      # @abstract
      # @raise [NotImplementedError] if not implemented in subclass.
      def and_then
        raise NotImplementedError, "#{self.class} must implement #and_then"
      end

      # Converts the outcome to a response object.
      #
      # @abstract
      # @raise [NotImplementedError] if not implemented in subclass.
      def to_response
        raise NotImplementedError, "#{self.class} must implement #to_response"
      end
    end

    # Represents a successful outcome of an interaction.
    class Success < Outcome
      # @return [Object] The value wrapped by this successful outcome.
      attr_reader :value

      # @param value [Object] The value to be wrapped in this successful outcome.
      def initialize(value)
        @value = value
      end

      # Chains another operation to be executed with the value of this outcome.
      #
      # @yield [Object] The value wrapped by this outcome.
      # @return [Outcome] The result of the yielded block.
      def and_then
        yield value
      end

      # Sets the response for this successful outcome.
      #
      # @param response [Plutonium::Interaction::Response::Base] The response to set.
      # @return [self]
      def with_response(response)
        @to_response = nil
        @response = response
        self
      end

      # Converts this successful outcome to a response object.
      #
      # @return [Plutonium::Interaction::Response::Base] The response object.
      def to_response
        @to_response ||= begin
          @response ||= Response::Null.new(value)
          @response.with_flash(messages)
        end
      end
    end

    # Represents a failed outcome of an interaction.
    class Failure < Outcome
      # @return [ActiveModel::Errors, Array<String>] The errors associated with this failure.
      attr_reader :errors

      # @param errors [ActiveModel::Errors, Array<String>] The errors to be wrapped in this failure.
      def initialize(errors)
        @errors = errors
      end

      # Returns self without executing the given block, propagating the failure.
      #
      # @return [self]
      def and_then
        self
      end

      # Returns self without setting a response.
      #
      # @return [self]
      def with_response(response)
        self
      end
    end
  end
end

require "active_model"

module Plutonium
  module Interaction
    # Base class for all interactions.
    # Provides core functionality for validations, execution, and result handling.
    #
    # @example
    #   class MyInteraction < Plutonium::Interaction::Base
    #     attribute :user_id, :integer
    #     validates :user_id, presence: true
    #
    #     private
    #
    #     def execute
    #       user = User.find(user_id)
    #       success(user)
    #     end
    #   end
    #
    # @note Subclasses must implement the #execute method.
    class Base
      include ActiveModel::Model
      include ActiveModel::Attributes
      # include Concerns::Presentable
      # include Concerns::WorkflowDSL

      # Executes the interaction with the given arguments.
      #
      # @param args [Hash] The arguments to initialize the interaction.
      # @return [Plutonium::Interaction::Outcome] The result of the interaction.
      def self.call(**args)
        new(**args).call
      end

      # Executes the interaction.
      #
      # @return [Plutonium::Interaction::Outcome] The result of the interaction.
      def call
        if valid?
          execute
        else
          failure(errors)
        end
      end

      private

      # Implement the main logic of the interaction.
      #
      # @abstract Subclass and override {#execute} to implement the interaction logic.
      # @return [Plutonium::Interaction::Outcome] The result of the interaction.
      # @raise [NotImplementedError] If the subclass doesn't implement this method.
      def execute
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      # Creates a successful outcome.
      #
      # @param value [Object] The value to be wrapped in the successful outcome.
      # @return [Plutonium::Interaction::Success] A successful outcome.
      def success(value)
        Success.new(value)
      end

      # Creates a failure outcome.
      #
      # @param errors [ActiveModel::Errors, Array<String>] The errors to be wrapped in the failure outcome.
      # @return [Plutonium::Interaction::Failure] A failure outcome.
      def failure(errors)
        Failure.new(errors)
      end
    end
  end
end

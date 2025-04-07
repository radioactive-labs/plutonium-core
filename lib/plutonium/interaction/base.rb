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
      include Plutonium::Definition::DefineableProps
      include Plutonium::Definition::ConfigAttr
      include Plutonium::Definition::Presentable
      include Plutonium::Definition::NestedInputs
      # include Plutonium::Interaction::Concerns::WorkflowDSL

      class Form < Plutonium::UI::Form::Interaction; end

      class << self
        def call(...)
          new(...).call
        end

        def build_form(instance)
          raise ArgumentError, "instance is required" unless instance

          self::Form.new(instance)
        end
      end

      config_attr :turbo
      defineable_props :field, :input

      attr_reader :view_context

      def initialize(view_context:, **attributes)
        super(attributes)
        @view_context = view_context
      end

      def build_form
        self.class.build_form(self)
      end

      # Executes the interaction.
      #
      # @return [Plutonium::Interaction::Outcome] The result of the interaction.
      def call
        if valid?
          outcome = execute
          unless outcome.is_a?(Plutonium::Interaction::Outcome)
            raise "#{self.class}#execute must return an instance of Plutonium::Interaction::Outcome.\n" \
                  "#{outcome.inspect} received instead"
          end
          outcome
        else
          failure.with_message("An error occurred")
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
      def succeed(value = nil)
        Plutonium::Interaction::Outcome::Success.new(value)
      end

      alias_method :success, :succeed

      def failed(errors = nil, attribute = :base)
        case errors
        when Hash
          errors.each { |attribute, error| self.errors.add(attribute, error) }
        else
          Array(errors).each { |error| self.errors.add(attribute, error) }
        end
        failure
      end

      # Creates a failure outcome.
      #
      # @param errors [ActiveModel::Errors, Array<String>] The errors to be wrapped in the failure outcome.
      # @return [Plutonium::Interaction::Failure] A failure outcome.
      def failure
        Plutonium::Interaction::Outcome::Failure.new
      end

      def current_user
        view_context.controller.helpers.current_user
      end
    end
  end
end

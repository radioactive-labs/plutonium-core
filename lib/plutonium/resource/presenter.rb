module Plutonium
  module Resource
    # Presenter class to define actions and fields for a resource
    # @abstract
    class Presenter
      include Plutonium::Core::Definers::FieldDefiner
      include Plutonium::Core::Definers::ActionDefiner

      # Initializes the presenter with context and resource record
      # @param [Object] context The context in which the presenter is used
      # @param [ActiveRecord::Base] resource_record The resource record being presented
      def initialize(context, resource_record)
        @context = context
        @resource_record = resource_record

        define_standard_actions
        define_actions
        define_fields
      end

      private

      attr_reader :context, :resource_record

      # Define fields for the resource
      # @note Override this in child presenters for custom field definitions
      def define_fields
      end

      # Define actions for the resource
      # @note Override this in child presenters for custom action definitions
      def define_actions
      end

      # Define standard actions for the resource
      def define_standard_actions
        define_action Plutonium::Core::Actions::NewAction.new(:new)
        define_action Plutonium::Core::Actions::ShowAction.new(:show)
        define_action Plutonium::Core::Actions::EditAction.new(:edit)
        define_action Plutonium::Core::Actions::DestroyAction.new(:destroy)
      end

      # Define an interactive action
      # @param [Symbol] name The name of the action
      # @param [Object] interaction The interaction object
      # @param [Hash] options Additional options for the action
      # @note This should be moved to its own definer
      def define_interactive_action(name, interaction:, **)
        define_action Plutonium::Core::Actions::InteractiveAction.new(name, interaction:, **)
      end

      # Define a nested input for the resource
      # @param [Symbol] name The name of the input
      # @param [Array] inputs The inputs for the nested field
      # @param [Class, nil] model_class The model class for the nested field
      # @param [Hash] options Additional options for the nested field
      # @yield [input] Gives the input object to the block
      # @note This should be moved to its own definer
      # @raise [ArgumentError] if model_class is not provided for polymorphic associations
      def define_nested_input(name, inputs:, model_class: nil, **options)
        nested_attribute_options = resource_class.all_nested_attributes_options[name]

        nested_attribute_options_class = nested_attribute_options&.[](:class)
        if nested_attribute_options_class.nil? && model_class.nil?
          raise ArgumentError, "model_class is required if your field is not an association or is polymorphic"
        end
        model_class ||= nested_attribute_options_class

        macro = nested_attribute_options&.[](:macro)
        allow_destroy = nested_attribute_options&.[](:allow_destroy).presence
        update_only = nested_attribute_options&.[](:update_only).presence
        limit = determine_nested_input_limit(macro, options[:limit], nested_attribute_options&.[](:limit))

        input = Plutonium::Core::Fields::Inputs::NestedInput.new(
          name,
          inputs:,
          allow_destroy: options.key?(:allow_destroy) ? options[:allow_destroy] : allow_destroy,
          update_only: options.key?(:update_only) ? options[:update_only] : update_only,
          limit: limit,
          resource_class: model_class,
          **options
        )
        yield input if block_given?

        define_input name, input:
      end

      # Determines the limit for a nested input
      # @param [Symbol, nil] macro The macro of the association
      # @param [Integer, nil] option_limit The limit provided in options
      # @param [Integer, nil] nested_attribute_limit The limit from nested attributes
      # @return [Integer, nil] The determined limit
      def determine_nested_input_limit(macro, option_limit, nested_attribute_limit)
        if macro == :has_one
          1
        elsif option_limit
          option_limit
        else
          nested_attribute_limit
        end
      end

      # Returns the resource class
      # @return [Class] The resource class
      def resource_class
        context.resource_class
      end
    end
  end
end

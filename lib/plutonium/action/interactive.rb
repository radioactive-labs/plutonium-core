# frozen_string_literal: true

module Plutonium
  module Action
    # InteractiveAction class for handling interactive actions in the Plutonium framework
    #
    # @attr_reader [Class] interaction The interaction class associated with this action
    # @attr_reader [Boolean] inline Whether the action is inline
    class Interactive < Base
      attr_reader :interaction, :inline

      # Initialize a new InteractiveAction
      #
      # @param [Symbol] name The name of the action
      # @param [Class] interaction The interaction class for this action
      # @param [Boolean] inline Whether the action is inline
      # @param [Hash] options Additional options for the action
      def initialize(name, interaction:, inline:, **)
        @interaction = interaction
        @inline = inline

        super(name, **)
      end

      # Get the confirmation message for the action
      #
      # @return [String, nil] The confirmation message or nil if not applicable
      def confirmation
        super || (@inline ? "#{label}?" : nil)
      end

      # Factory for creating Interactive actions
      class Factory
        # Create a new Interactive action based on the interaction type
        #
        # @param [Symbol] name The name of the action
        # @param [Class] interaction The interaction class
        # @param [Hash] options Additional options for the action
        # @return [Interactive] A new Interactive action instance
        def self.create(name, interaction:, **options)
          attribute_names = symbolized_attribute_names(interaction)
          action_type = determine_action_type(attribute_names)
          input_fields = determine_input_fields(attribute_names)
          action_options = determine_action_options(action_type)
          inline = options.fetch(:inline) { input_fields.blank? }
          route_options = build_route_options(name, action_type, inline)

          Interactive.new(
            name,
            interaction: interaction,
            inline: inline,
            route_options: route_options,
            **action_options,
            **options
          )
        end

        # Get symbolized attribute names for the interaction
        #
        # @param [Class] interaction The interaction class
        # @return [Array<Symbol>] Symbolized attribute names
        def self.symbolized_attribute_names(interaction)
          interaction.attribute_names.map(&:to_sym)
        end

        # Determine the action type based on the interaction's attributes
        #
        # @param [Array<Symbol>] attribute_names Symbolized attribute names
        # @return [Symbol] The determined action type
        def self.determine_action_type(attribute_names)
          if attribute_names.include?(:resource)
            :interactive_resource_record_action
          elsif attribute_names.include?(:resources)
            :interactive_resource_collection_action
          else
            :interactive_resource_recordless_action
          end
        end

        # Determine the input fields for the action
        #
        # @param [Array<Symbol>] attribute_names Symbolized attribute names
        # @return [Array<Symbol>] The input fields
        def self.determine_input_fields(attribute_names)
          attribute_names - [:resource, :resources]
        end

        # Determine the action options based on the action type
        #
        # @param [Symbol] action_type The type of the action
        # @return [Hash] The action options
        def self.determine_action_options(action_type)
          {
            collection_action: action_type == :interactive_resource_collection_action,
            record_action: action_type == :interactive_resource_record_action,
            collection_record_action: action_type == :interactive_resource_record_action,
            global_action: action_type == :interactive_resource_recordless_action
          }
        end

        # Build the route options for the action
        #
        # @param [Symbol] name The name of the action
        # @param [Symbol] action_type The type of the action
        # @param [Boolean] inline Whether the action is inline
        # @return [RouteOptions] The route options for the action
        def self.build_route_options(name, action_type, inline)
          RouteOptions.new(
            method: inline ? :post : :get,
            action: action_type,
            interactive_action: name
          )
        end
      end
    end
  end
end

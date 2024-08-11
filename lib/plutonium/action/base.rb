# frozen_string_literal: true

module Plutonium
  module Action
    # Base class for all actions in the Plutonium framework.
    #
    # @attr_reader [Symbol] name The name of the action.
    # @attr_reader [String] label The human-readable label for the action.
    # @attr_reader [String, nil] icon The icon associated with the action.
    # @attr_reader [RouteOptions] route_options The routing options for the action.
    # @attr_reader [String, nil] confirmation The confirmation message for the action.
    # @attr_reader [String, nil] turbo_frame The Turbo Frame ID for the action.
    # @attr_reader [Symbol, nil] color The color associated with the action.
    # @attr_reader [Symbol, nil] category The category of the action.
    # @attr_reader [Integer] position The position of the action within its category.
    class Base
      attr_reader :name, :label, :icon, :route_options, :confirmation, :turbo_frame, :color, :category, :position

      # Initialize a new action.
      #
      # @param [Symbol] name The name of the action.
      # @param [Hash] options The options for the action.
      # @option options [String] :label The human-readable label for the action.
      # @option options [String] :icon The icon associated with the action (e.g., 'fa-edit' for Font Awesome).
      # @option options [Symbol] :color The color associated with the action (e.g., :primary, :secondary).
      # @option options [String] :confirmation The confirmation message to display before executing the action.
      # @option options [RouteOptions, Hash] :route_options The routing options for the action.
      # @option options [String] :turbo_frame The Turbo Frame ID for the action (used in Hotwire/Turbo Drive applications).
      # @option options [Boolean] :collection_action (false) If true, applies bulk actions to a selection of records (e.g., "Mark Selected as Read").
      # @option options [Boolean] :collection_record_action (false) If true, applies to each record in a collection (e.g., "Edit Record" button in a list).
      # @option options [Boolean] :record_action (false) If true, applies to a single individual record (e.g., "Delete" button on a Show page).
      # @option options [Boolean] :global_action (false) If true, applies to the entire resource and can be used in any context (e.g., "Import from CSV").
      # @option options [Symbol] :category The category of the action. Determines visibility and grouping.
      #   Valid values include:
      #   @option options [Symbol] :primary Always shown and given prominence in the UI.
      #   @option options [Symbol] :secondary Shown in secondary menus or less prominent areas.
      #   @option options [Symbol] :danger Actions that require caution, often destructive operations.
      # @option options [Integer] :position (50) The position of the action in its group. Lower numbers appear first.
      def initialize(name, **options)
        @name = name.to_sym
        @label = options[:label] || name.to_s.humanize
        @icon = options[:icon]
        @color = options[:color]
        @confirmation = options[:confirmation]
        @route_options = build_route_options(options[:route_options])
        @turbo_frame = options[:turbo_frame]
        @collection_action = options[:collection_action] || false
        @collection_record_action = options[:collection_record_action] || false
        @record_action = options[:record_action] || false
        @global_action = options[:global_action] || false
        @category = options[:category]
        @position = options[:position] || 50

        freeze
      end

      # @return [Boolean] Whether this is a collection action.
      def collection_action?
        @collection_action
      end

      # @return [Boolean] Whether this is a collection record action.
      def collection_record_action?
        @collection_record_action
      end

      # @return [Boolean] Whether this is a record action.
      def record_action?
        @record_action
      end

      # @return [Boolean] Whether this is a bulk action.
      def global_action?
        @global_action
      end

      private

      # Build RouteOptions from the provided options
      #
      # @param [RouteOptions, Hash, nil] options The routing options
      # @return [RouteOptions] The built RouteOptions object
      def build_route_options(options)
        case options
        when RouteOptions
          options
        when Hash
          RouteOptions.new(**options)
        when nil
          RouteOptions.new
        else
          raise ArgumentError, "Invalid route_options. Expected RouteOptions, Hash, or nil."
        end
      end
    end
  end
end

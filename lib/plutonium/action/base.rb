# frozen_string_literal: true

require "active_support/string_inquirer"

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
      attr_reader :name, :label, :description, :icon, :route_options, :confirmation, :turbo, :turbo_frame, :color, :category, :position

      # Initialize a new action.
      #
      # @param [Symbol] name The name of the action.
      # @param [Hash] options The options for the action.
      # @option options [String] :label The human-readable label for the action.
      # @option options [String] :description The human-readable description for the action.
      # @option options [String] :icon The icon associated with the action (e.g., 'fa-edit' for Font Awesome).
      # @option options [Symbol] :color The color associated with the action (e.g., :primary, :secondary, :success, :warning, :danger).
      # @option options [String] :confirmation The confirmation message to display before executing the action.
      # @option options [RouteOptions, Hash] :route_options The routing options for the action.
      # @option options [String] :turbo_frame The Turbo Frame ID for the action (used in Hotwire/Turbo Drive applications).
      # @option options [Boolean] :bulk_action (false) If true, applies to a bulk selection of records (e.g., "Mark Selected as Read").
      # @option options [Boolean] :collection_record_action (false) If true, applies to records in a collection (e.g., "Edit Record" button in a table).
      # @option options [Boolean] :record_action (false) If true, applies to an individual record (e.g., "Delete" button on a Show page).
      # @option options [Boolean] :resource_action (false) If true, applies to the entire resource and can be used in any context (e.g., "Import from CSV").
      # @option options [Symbol] :category The category of the action. Determines visibility and grouping.
      #   Valid values include:
      #   @option options [Symbol] :primary Always shown and given prominence in the UI.
      #   @option options [Symbol] :secondary Shown in secondary menus or less prominent areas.
      #   @option options [Symbol] :danger Actions that require caution, often destructive operations.
      # @option options [Integer] :position (50) The position of the action in its group. Lower numbers appear first.
      def initialize(name, **options)
        @name = name.to_sym
        @label = options[:label] || @name.to_s.titleize
        @description = options[:description]
        @icon = options[:icon] || Phlex::TablerIcons::ChevronRight
        @color = options[:color]
        @confirmation = options[:confirmation]
        @route_options = build_route_options(options[:route_options])
        @turbo = options[:turbo]
        @turbo_frame = options[:turbo_frame]
        @bulk_action = options[:bulk_action] || false
        @collection_record_action = options[:collection_record_action] || false
        @record_action = options[:record_action] || false
        @resource_action = options[:resource_action] || false
        @category = ActiveSupport::StringInquirer.new((options[:category] || :secondary).to_s)
        @position = options[:position] || 50

        freeze
      end

      # @return [Boolean] Whether this is a bulk action.
      def bulk_action?
        @bulk_action
      end

      # @return [Boolean] Whether this is a collection record action.
      def collection_record_action?
        @collection_record_action
      end

      # @return [Boolean] Whether this is a record action.
      def record_action?
        @record_action
      end

      # @return [Boolean] Whether this is a resource action.
      def resource_action?
        @resource_action
      end

      def permitted_by?(policy)
        policy.allowed_to?(:"#{name}?")
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
        when Array
          kwargs = options.extract_options!
          RouteOptions.new(*options, **kwargs)
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

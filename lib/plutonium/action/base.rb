# frozen_string_literal: true

require "active_support/string_inquirer"

module Plutonium
  module Action
    # Base class for all actions in the Plutonium framework.
    class Base
      attr_reader :name, :label, :description, :icon, :route_options, :confirmation, :turbo, :color, :category, :position, :return_to, :condition

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
        @return_to = options[:return_to]
        @bulk_action = options[:bulk_action] || false
        @collection_record_action = options[:collection_record_action] || false
        @record_action = options[:record_action] || false
        @resource_action = options[:resource_action] || false
        @category = ActiveSupport::StringInquirer.new((options[:category] || :secondary).to_s)
        @position = options[:position] || 50
        @modal_mode = options[:modal]
        @modal_size = options[:size]
        @condition = options[:condition]
        validate_modal_mode!
        validate_modal_size!

        freeze
      end

      # Resolves to the definition's `modal_mode` when unset on the action.
      def modal_mode(definition = nil)
        return @modal_mode if @modal_mode || definition.nil?
        definition.modal_mode
      end

      # Resolves to the definition's `modal_size` when unset on the action.
      def modal_size(definition = nil)
        return @modal_size if @modal_size || definition.nil?
        definition.modal_size
      end

      # Downgrades the remote-modal frame to nil when the definition has
      # `modal false`, so the link navigates as a full page instead of
      # targeting a frame that won't exist. Other frames pass through.
      def turbo_frame(definition = nil)
        return nil if definition && targets_remote_modal? && definition.modal_mode == false
        @turbo_frame
      end

      def bulk_action? = @bulk_action
      def collection_record_action? = @collection_record_action
      def record_action? = @record_action
      def resource_action? = @resource_action

      def permitted_by?(policy)
        policy.allowed_to?(:"#{name}?")
      end

      # Display-only visibility gate, mirroring the `condition:` proc on
      # inputs/displays/columns. Returns true when no condition is set.
      #
      # The proc is evaluated against a ConditionContext: `object`/`record` is
      # the contextual record (nil for resource/bulk actions), and every other
      # call delegates to the view context (current_user, params, request,
      # allowed_to?, resource_record!, …).
      #
      # NOT an authorization boundary — a hidden action still has a live route;
      # keep authorization in the policy.
      def condition_met?(view_context, record: nil)
        return true if @condition.nil?
        ConditionContext.new(view_context, record).instance_exec(&@condition)
      end

      # Returns a new Action with the given options merged over this one.
      def with(**overrides)
        self.class.new(name, **to_options.merge(overrides))
      end

      protected

      # Canonical option hash for reconstruction via `with`. Every
      # attribute set in `initialize` MUST appear here; otherwise
      # `with(**overrides)` would silently drop it on round-trip.
      def to_options
        {
          label: @label,
          description: @description,
          icon: @icon,
          color: @color,
          confirmation: @confirmation,
          route_options: @route_options,
          turbo: @turbo,
          turbo_frame: @turbo_frame,
          return_to: @return_to,
          bulk_action: @bulk_action,
          collection_record_action: @collection_record_action,
          record_action: @record_action,
          resource_action: @resource_action,
          category: @category.to_sym,
          position: @position,
          modal: @modal_mode,
          size: @modal_size,
          condition: @condition
        }
      end

      private

      def targets_remote_modal?
        @turbo_frame == Plutonium::REMOTE_MODAL_FRAME
      end

      def validate_modal_mode!
        return if @modal_mode.nil?
        return if [:centered, :slideover].include?(@modal_mode)
        raise ArgumentError, "modal must be :centered or :slideover, got #{@modal_mode.inspect}"
      end

      def validate_modal_size!
        return if @modal_size.nil?
        return if Plutonium::UI::Modal::Base::VALID_SIZES.include?(@modal_size)
        raise ArgumentError,
          "size must be one of #{Plutonium::UI::Modal::Base::VALID_SIZES.inspect}, " \
            "got #{@modal_size.inspect}"
      end

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

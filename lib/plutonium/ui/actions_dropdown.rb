# frozen_string_literal: true

module Plutonium
  module UI
    # Dropdown menu for secondary and danger actions
    # Groups actions by category with danger actions shown after a divider
    class ActionsDropdown < Plutonium::UI::Component::Base
      def initialize(actions:, subject:)
        @actions = actions
        @subject = subject
      end

      def view_template
        div(data: {controller: "resource-drop-down"}) do
          render_trigger_button
          render_dropdown_menu
        end
      end

      private

      def render_trigger_button
        button(
          type: "button",
          class: "pu-btn pu-btn-md pu-btn-outline",
          aria: {expanded: "false", haspopup: "true"},
          data: {resource_drop_down_target: "trigger"}
        ) do
          span(class: "sr-only") { "Open actions menu" }
          plain "Actions"
          render Phlex::TablerIcons::ChevronDown.new(class: "w-4 h-4 ml-1")
        end
      end

      def render_dropdown_menu
        div(
          class: "hidden absolute right-0 z-50 mt-2 w-48 origin-top-right bg-[var(--pu-surface)] border border-[var(--pu-border)] rounded-[var(--pu-radius-lg)] overflow-hidden",
          style: "box-shadow: var(--pu-shadow-lg)",
          data: {resource_drop_down_target: "menu"}
        ) do
          render_secondary_actions if secondary_actions.any?
          render_danger_divider if secondary_actions.any? && danger_actions.any?
          render_danger_actions if danger_actions.any?
        end
      end

      def render_secondary_actions
        div(class: "py-1") do
          secondary_actions.each { |action| render_action_item(action) }
        end
      end

      def render_danger_divider
        div(class: "border-t border-[var(--pu-border-muted)]")
      end

      def render_danger_actions
        div(class: "py-1") do
          danger_actions.each { |action| render_action_item(action, danger: true) }
        end
      end

      def render_action_item(action, danger: false)
        url = route_options_to_url(action.route_options, @subject)

        link_attrs = {
          href: url,
          class: tokens(
            "flex items-center gap-2 px-4 py-2 text-sm transition-colors",
            danger ? "text-danger-600 dark:text-danger-400 hover:bg-danger-50 dark:hover:bg-danger-900/30" : "text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
          )
        }

        # Add turbo frame if specified
        link_attrs[:data] = {turbo_frame: action.turbo_frame} if action.turbo_frame

        # Add confirmation if specified
        if action.confirmation
          link_attrs[:data] ||= {}
          link_attrs[:data][:turbo_method] = :delete if action.route_options.method == :delete
          link_attrs[:data][:turbo_confirm] = action.confirmation
        end

        a(**link_attrs) do
          render action.icon.new(class: "w-4 h-4") if action.icon
          span { action.label }
        end
      end

      def secondary_actions
        @secondary_actions ||= @actions.select { |a| a.category.secondary? }.sort_by(&:position)
      end

      def danger_actions
        @danger_actions ||= @actions.select { |a| a.category.danger? }.sort_by(&:position)
      end

      def render?
        @actions.any?
      end
    end
  end
end

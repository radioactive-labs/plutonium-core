# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # Dropdown menu for secondary and danger row actions in tables
        # Shows a compact icon trigger with grouped actions
        class RowActionsDropdown < Plutonium::UI::Component::Base
          def initialize(actions:, record:)
            @actions = actions
            @record = record
          end

          def view_template
            div(class: "relative", data: {controller: "resource-drop-down"}) do
              render_trigger_button
              render_dropdown_menu
            end
          end

          private

          def render_trigger_button
            button(
              type: "button",
              class: "p-1.5 rounded-[var(--pu-radius-md)] border border-[var(--pu-border)] bg-[var(--pu-surface)] text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] hover:border-[var(--pu-border-strong)] transition-colors",
              aria: {expanded: "false", haspopup: "true", label: "More actions"},
              data: {resource_drop_down_target: "trigger"}
            ) do
              render Phlex::TablerIcons::DotsVertical.new(class: "w-4 h-4")
            end
          end

          def render_dropdown_menu
            div(
              class: "hidden absolute right-0 z-50 mt-1 w-40 origin-top-right bg-[var(--pu-surface)] border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] overflow-hidden",
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
              danger_actions.each { |action| render_action_item(action) }
            end
          end

          def render_action_item(action)
            url = route_options_to_url(action.route_options, @record)
            render Plutonium::UI::ActionButton.new(action, url: url, variant: :row_dropdown)
          end

          def secondary_actions
            @secondary_actions ||= @actions.select { |a| a.category.secondary? }.sort_by(&:position)
          end

          def danger_actions
            @danger_actions ||= @actions.select { |a| a.category.danger? }.sort_by(&:position)
          end
        end
      end
    end
  end
end

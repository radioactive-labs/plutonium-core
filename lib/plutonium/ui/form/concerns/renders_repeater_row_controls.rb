# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Concerns
        # Shared chrome for removable repeater rows (structured inputs and
        # nested resource fields): the "Remove" button and the compact
        # "Removed — Restore" accent bar shown in its place. Centralising these
        # keeps the two concerns visually in lockstep.
        # @api private
        module RendersRepeaterRowControls
          extend ActiveSupport::Concern

          private

          REMOVE_BUTTON_CLASS =
            "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium rounded-lg cursor-pointer " \
            "text-danger-700 hover:bg-danger-50 dark:text-danger-400 dark:hover:bg-danger-950/30 " \
            "focus:outline-none focus:ring-4 focus:ring-danger-200 dark:focus:ring-danger-900"

          RESTORE_BUTTON_CLASS =
            "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium rounded-lg cursor-pointer " \
            "text-secondary-700 hover:bg-secondary-100 dark:text-secondary-300 dark:hover:bg-secondary-900/40 " \
            "focus:outline-none focus:ring-4 focus:ring-secondary-200 dark:focus:ring-secondary-900"

          # Right-aligned "Remove" button that triggers the row's remove action.
          def render_repeater_remove_button(action:)
            div(class: "flex items-center justify-end") do
              button(type: :button, class: REMOVE_BUTTON_CLASS, data_action: action) do
                render Phlex::TablerIcons::Trash.new(class: "w-4 h-4")
                span { "Remove" }
              end
            end
          end

          # Compact accent bar shown in place of a removed row. Negative margin
          # cancels the row's padding so the bar fills the fieldset edge-to-edge;
          # a left danger stripe + struck-through label read as "pending delete".
          #
          # @param restore_action [String] Stimulus action for the Restore button
          # @param label [String] text shown beside the trash icon
          # @param bar_data [Hash] extra data attributes (Stimulus target/marker)
          #   the controller uses to find and toggle this bar
          def render_repeater_removed_bar(restore_action:, label: "Removed", **bar_data)
            div(
              hidden: true,
              class: "-m-4 flex items-center justify-between gap-3 px-4 py-2.5 " \
                     "rounded-[var(--pu-radius-md)] border-l-4 border-danger-400 dark:border-danger-600 " \
                     "bg-danger-50/70 dark:bg-danger-950/20",
              **bar_data
            ) do
              span(class: "inline-flex items-center gap-2 text-sm text-[var(--pu-text-muted)]") do
                render Phlex::TablerIcons::Trash.new(class: "w-4 h-4 shrink-0 text-danger-500 dark:text-danger-400")
                span(class: "line-through decoration-danger-400/60") { label }
              end
              button(type: :button, class: RESTORE_BUTTON_CLASS, data_action: restore_action) do
                render Phlex::TablerIcons::ArrowBackUp.new(class: "w-4 h-4")
                span { "Restore" }
              end
            end
          end
        end
      end
    end
  end
end

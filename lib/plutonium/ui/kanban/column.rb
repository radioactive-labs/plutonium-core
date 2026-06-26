# frozen_string_literal: true

module Plutonium
  module UI
    module Kanban
      # Renders a single column body: header with wip badge, card list, and a
      # "+N more" footer when the total exceeds per_column.
      #
      # This is the component that Task 6's lazy frame endpoint serves. The
      # board shell (Resource) wraps each column in a <turbo-frame>; the frame
      # src hits the column endpoint which renders this component as the body.
      #
      # Collapsed variant: when column.collapsed? the component renders a thin
      # rotated-label strip instead of the full card list. The user can expand
      # it later (Task 13 wires the toggle).
      #
      # Action slot: column.actions are rendered as minimal placeholder buttons
      # so the DOM seam is in place for Task 8 which wires the actual action
      # handlers (interactive bulk actions). The buttons carry data-kanban-action
      # and data-kanban-column attributes for Stimulus targeting.
      class Column < Plutonium::UI::Component::Base
        attr_reader :column, :cards, :total, :per_column, :resource_definition, :resource_fields

        def initialize(column:, cards:, total:, per_column:, resource_definition:, resource_fields:)
          @column = column
          @cards = cards
          @total = total
          @per_column = per_column
          @resource_definition = resource_definition
          @resource_fields = resource_fields
        end

        def view_template
          column.collapsed? ? render_collapsed_strip : render_expanded
        end

        private

        # ---------------------------------------------------------------
        # Collapsed strip
        # ---------------------------------------------------------------

        def render_collapsed_strip
          div(
            class: "pu-kanban-column-collapsed w-10 flex flex-col items-center justify-between " \
                   "py-3 gap-2 bg-[var(--pu-surface)] border border-[var(--pu-border)] " \
                   "rounded-[var(--pu-radius-md)] select-none",
            data: {kanban_column_key: column.key.to_s}
          ) do
            span(
              class: "text-xs font-semibold text-[var(--pu-text-muted)] " \
                     "[writing-mode:vertical-lr] rotate-180",
            ) { plain column.label }
            span(class: "pu-badge pu-badge-neutral text-xs font-mono") { plain cards.size.to_s }
          end
        end

        # ---------------------------------------------------------------
        # Expanded column
        # ---------------------------------------------------------------

        def render_expanded
          div(
            class: "pu-kanban-column w-72 shrink-0 flex flex-col bg-[var(--pu-surface-alt)] " \
                   "border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] overflow-hidden",
            data: {kanban_column_key: column.key.to_s}
          ) do
            render_header
            render_card_list
            render_more_footer if more_count > 0
          end
        end

        def render_header
          div(class: "px-3 py-2 flex items-center justify-between gap-2 border-b border-[var(--pu-border)] bg-[var(--pu-surface)]") do
            div(class: "flex items-center gap-2 min-w-0 flex-1") do
              span(class: "font-semibold text-sm text-[var(--pu-text)] truncate") { plain column.label }
              render_wip_badge if column.wip
            end
            render_column_actions if column.actions.any?
          end
        end

        def render_wip_badge
          over = wip_over_limit?
          span(
            class: tokens(
              "pu-badge text-xs font-mono",
              over ? "pu-badge-danger" : "pu-badge-neutral"
            ),
            title: over ? "WIP limit exceeded" : "WIP limit: #{column.wip}"
          ) do
            plain "#{cards.size}/#{column.wip}"
          end
        end

        # ---------------------------------------------------------------
        # Card list
        # ---------------------------------------------------------------

        def render_card_list
          div(
            class: "flex flex-col gap-2 p-2 min-h-[3rem] flex-1",
            data: {
              kanban_target: "column",
              kanban_column_key_value: column.key.to_s
            }
          ) do
            render_cards
          end
        end

        # Extracted so tests can stub render_cards without needing a real
        # view_context (Grid::Card requires policy_for etc.).
        def render_cards
          cards.each do |record|
            render Plutonium::UI::Kanban::Card.new(
              record,
              column_key: column.key,
              resource_definition: resource_definition,
              resource_fields: resource_fields
            )
          end
        end

        # ---------------------------------------------------------------
        # "+N more" footer
        # ---------------------------------------------------------------

        def render_more_footer
          div(class: "px-3 py-2 border-t border-[var(--pu-border)] bg-[var(--pu-surface)]") do
            span(class: "text-xs text-[var(--pu-text-muted)]") do
              plain "+#{more_count} more"
            end
          end
        end

        # ---------------------------------------------------------------
        # Column action slot (Task 8 hook)
        # ---------------------------------------------------------------

        # Renders placeholder buttons for each column action. Task 8 replaces
        # these with fully-wired interactive bulk action handlers. The data
        # attributes are the targeting seam for the Stimulus controller.
        def render_column_actions
          div(class: "flex items-center gap-1 shrink-0") do
            column.actions.each do |action|
              button(
                type: "button",
                class: "pu-btn pu-btn-ghost pu-btn-xs text-[var(--pu-text-muted)]",
                data: {
                  kanban_action: action.key.to_s,
                  kanban_column: column.key.to_s
                },
                title: action.label || action.key.to_s.humanize
              ) do
                plain action.label || action.key.to_s.humanize
              end
            end
          end
        end

        # ---------------------------------------------------------------
        # Pure helpers
        # ---------------------------------------------------------------

        def wip_over_limit?
          column.wip && cards.size > column.wip
        end

        def more_count
          [total - cards.size, 0].max
        end
      end
    end
  end
end

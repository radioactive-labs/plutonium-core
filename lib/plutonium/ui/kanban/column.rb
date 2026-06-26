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
        include Phlex::Rails::Helpers::LinkTo

        attr_reader :column, :cards, :total, :per_column, :resource_definition, :resource_fields

        # column_action_data: array of {action: Plutonium::Kanban::Action, ids: [Integer, ...]}
        # Resolved by the controller (KanbanActions#render_kanban_column_html) and
        # threaded here so the component can render real bulk-action links without
        # needing to re-query the DB.  Defaults to [] when the component is
        # constructed outside of a controller context (e.g., tests or the board
        # shell which renders column frames without card data).
        def initialize(column:, cards:, total:, per_column:, resource_definition:, resource_fields:, column_action_data: [])
          @column = column
          @cards = cards
          @total = total
          @per_column = per_column
          @resource_definition = resource_definition
          @resource_fields = resource_fields
          @column_action_data = column_action_data
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
            render_column_actions if column.actions.any?
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
        # Column action slot
        # ---------------------------------------------------------------

        # Renders bulk-action links for each column action.
        #
        # Each link targets GET /resources/bulk_actions/:key?ids[]=…, which is
        # the existing interactive_bulk_action route.  The action is only rendered
        # when:
        #   1. The resolved action is registered in defined_actions (auto-registered
        #      by Definition::IndexViews.kanban at class-load time).
        #   2. current_policy.allowed_to?(:"#{key}?") returns true.
        #
        # The bulk endpoint re-authorizes each record individually, so this
        # check is a display-only gate — not the security boundary.
        def render_column_actions
          div(class: "flex items-center gap-1 shrink-0") do
            @column_action_data.each do |entry|
              col_action = entry[:action]
              ids = entry[:ids]

              registered = current_definition.defined_actions[col_action.key]
              next unless registered&.permitted_by?(current_policy)

              url = resource_url_for(resource_class, interaction: col_action.key, ids: ids)
              label = col_action.label || col_action.key.to_s.humanize
              data_attrs = {
                kanban_action: col_action.key.to_s,
                kanban_column: column.key.to_s
              }
              data_attrs[:turbo_confirm] = col_action.confirmation if col_action.confirmation

              link_to(
                url,
                class: "pu-btn pu-btn-ghost pu-btn-xs text-[var(--pu-text-muted)]",
                title: label,
                data: data_attrs
              ) do
                plain label
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

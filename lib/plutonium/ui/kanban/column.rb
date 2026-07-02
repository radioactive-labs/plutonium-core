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
      # rotated-label strip instead of the full card list. Both the strip and
      # the expanded body are always emitted in the HTML; CSS (controlled by
      # the `pu-kanban-column-collapsed` class on the wrapper) shows one and
      # hides the other. The Stimulus controller's toggleColumn action flips the
      # class and persists the choice to localStorage.
      #
      # Action slot: column.actions are rendered as minimal placeholder buttons
      # so the DOM seam is in place for Task 8 which wires the actual action
      # handlers (interactive bulk actions). The buttons carry data-kanban-action
      # and data-kanban-column attributes for Stimulus targeting.
      #
      # Drop policy: the wrapper emits data-kanban-accepts and data-kanban-locked
      # so the Stimulus drag controller can provide client-side drop hints without
      # re-implementing server-side logic. The server remains the authority.
      class Column < Plutonium::UI::Component::Base
        include ColorDot
        include Phlex::Rails::Helpers::LinkTo

        attr_reader :column, :cards, :total, :per_column, :resource_definition, :resource_fields

        # column_action_data: array of {action: Plutonium::Kanban::Action, ids: [Integer, ...]}
        # Resolved by the controller (KanbanActions#render_kanban_column_html) and
        # threaded here so the component can render real bulk-action links without
        # needing to re-query the DB.  Defaults to [] when the component is
        # constructed outside of a controller context (e.g., tests or the board
        # shell which renders column frames without card data).
        #
        # column_add_url: URL for the "+ Add" quick-add button (or nil).
        # Set by the controller when column.add? is true and the policy permits
        # create. Carries kanban_column=<key> so the new form pre-fills the
        # grouping attribute via apply_kanban_column_defaults!.
        #
        # card_fields: optional slot-layout hash from the board's card_fields
        # declaration (e.g. { header: :title, meta: [:status] }).  Threaded
        # through to each Kanban::Card (and ultimately Grid::Card) so it
        # overrides the resource definition's grid_fields for every card in the
        # column.  nil means "use the definition's grid_fields" (default).
        # card_show_frame: the turbo-frame each card's show link targets — the
        # remote-modal frame (board show_in :modal) or "_top" (show_in :page).
        # Resolved by the controller and threaded through to Kanban::Card.
        # Defaults to "_top" so a card always escapes the column's lazy frame when
        # the component is built outside a controller (tests, board shell).
        def initialize(column:, cards:, total:, per_column:, resource_definition:, resource_fields:, column_action_data: [], column_add_url: nil, card_fields: nil, card_show_frame: "_top")
          @column = column
          @cards = cards
          @total = total
          @per_column = per_column
          @resource_definition = resource_definition
          @resource_fields = resource_fields
          @column_action_data = column_action_data
          @column_add_url = column_add_url
          @card_fields = card_fields
          @card_show_frame = card_show_frame
        end

        def view_template
          # Wrapper carries the drop-policy data attributes and the initial
          # collapsed CSS class. The Stimulus controller reads data-kanban-col
          # to find wrappers unambiguously (distinct from toggle button attrs).
          div(
            class: tokens(
              "pu-kanban-column-wrapper",
              column.collapsed? && "pu-kanban-column-collapsed"
            ),
            data: {
              kanban_col: column.key.to_s,
              kanban_accepts: accepts_value,
              kanban_locked: column.locked?.to_s
            }
          ) do
            render_collapsed_strip
            render_expanded
          end
        end

        private

        # ---------------------------------------------------------------
        # Collapsed strip
        # ---------------------------------------------------------------

        def render_collapsed_strip
          # CSS hides this strip when the wrapper lacks pu-kanban-column-collapsed.
          # Always emitted so the JS toggle can switch between strip and body
          # without a server round-trip.
          div(
            class: "pu-kanban-strip w-10 flex flex-col items-center justify-between " \
                   "py-3 gap-2 bg-[var(--pu-surface)] border border-[var(--pu-border)] " \
                   "rounded-[var(--pu-radius-md)] select-none",
            data: {kanban_role: "strip"}
          ) do
            span(
              class: "text-xs font-semibold text-[var(--pu-text-muted)] " \
                     "[writing-mode:vertical-lr] rotate-180"
            ) { plain column.label }
            span(class: "pu-badge pu-badge-neutral text-xs font-mono") { plain cards.size.to_s }
            # Expand toggle button — the primary interactive seam for
            # collapsing/expanding. data-kanban-column-key is on this button so
            # the integration test can assert the contract without JS execution.
            button(
              class: "p-0.5 rounded text-[var(--pu-text-muted)] " \
                     "hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]",
              title: "Expand #{column.label}",
              type: "button",
              data: {
                action: "click->kanban#toggleColumn",
                kanban_column_key: column.key.to_s
              }
            ) { plain "▶" }
            # No column actions here: a collapsed column is a thin strip, so its
            # bulk actions (and "+ Add") stay hidden until it's expanded. They
            # live only in the expanded header (render_header).
          end
        end

        # ---------------------------------------------------------------
        # Expanded column
        # ---------------------------------------------------------------

        def render_expanded
          # CSS hides this body when the wrapper has pu-kanban-column-collapsed.
          div(
            class: "pu-kanban-body pu-kanban-column w-72 shrink-0 flex flex-col " \
                   "bg-[var(--pu-surface-alt)] border border-[var(--pu-border)] " \
                   "rounded-[var(--pu-radius-md)] overflow-hidden",
            data: {kanban_role: "body"}
          ) do
            render_header
            render_card_list
            render_more_footer if more_count > 0
          end
        end

        def render_header
          div(class: "px-3 py-2 flex items-center justify-between gap-2 border-b border-[var(--pu-border)] bg-[var(--pu-surface)]") do
            div(class: "flex items-center gap-2 min-w-0 flex-1") do
              render_color_dot(column.color) if column.color
              span(class: "font-semibold text-sm text-[var(--pu-text)] truncate") { plain column.label }
              render_wip_badge if column.wip
            end
            render_column_actions if @column_add_url || column.actions.any?
            # Collapse toggle — always present in the expanded header so the
            # user can collapse a column even when no other actions are visible.
            # Kept outside render_column_actions so the action-slot tests are
            # unaffected (they check the flex-gap container which is conditional).
            button(
              class: "shrink-0 p-0.5 rounded text-[var(--pu-text-muted)] " \
                     "hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]",
              title: "Collapse #{column.label}",
              type: "button",
              data: {
                action: "click->kanban#toggleColumn",
                kanban_column_key: column.key.to_s
              }
            ) { plain "◀" }
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
              resource_fields: resource_fields,
              card_fields: @card_fields,
              show_turbo_frame: @card_show_frame
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

        # Renders the "+ Add" quick-add button that opens the resource's new form
        # in the remote modal frame, pre-seeded for this column.
        def render_add_button
          link_to(
            @column_add_url,
            class: "pu-btn pu-btn-ghost pu-btn-xs text-[var(--pu-text-muted)]",
            title: "Add to #{column.label}",
            data: {turbo_frame: Plutonium::REMOTE_MODAL_FRAME}
          ) do
            plain "+ Add"
          end
        end

        # Renders bulk-action links for each column action, and the "+ Add"
        # quick-add button when column_add_url is present.
        #
        # Each link targets /resources/bulk_actions/:key?ids[]=… — the same path
        # for the GET form and the POST commit. The render mirrors ActionButton so
        # the action's shape is honoured (see #column_action_link_data):
        #   • an interaction with NO user inputs is `immediate` → POST + confirm,
        #     executed directly instead of opening an empty form modal;
        #   • one with inputs opens the interaction form in the remote modal.
        #
        # The action is only rendered when it's registered in defined_actions
        # (auto-registered by Definition::IndexViews.kanban) and permitted by the
        # policy. The bulk endpoint re-authorizes each record, so this is a
        # display-only gate, not the security boundary.
        def render_column_actions
          div(class: "flex items-center gap-1 shrink-0") do
            render_add_button if @column_add_url
            @column_action_data.each do |entry|
              col_action = entry[:action]
              ids = entry[:ids]

              registered = current_definition.defined_actions[col_action.key]
              next unless registered&.permitted_by?(current_policy)

              # Skip when the resolved id set is empty: resource_url_for with
              # ids: [] would resolve to the RESOURCE action route
              # (/resource_actions/:key) rather than the bulk route, misfiring
              # if clicked. An empty column simply renders no action link.
              next if ids.empty?

              url = resource_url_for(resource_class, interaction: col_action.key, ids: ids)
              label = col_action.label || col_action.key.to_s.humanize

              link_to(
                url,
                class: "pu-btn pu-btn-ghost pu-btn-xs text-[var(--pu-text-muted)]",
                title: label,
                data: column_action_link_data(col_action, registered)
              ) do
                render col_action.icon.new(class: "h-4 w-4") if col_action.icon
                plain label
              end
            end
          end
        end

        # Data attributes for a column-action link, honouring the interaction's
        # shape. `immediate` actions (no inputs) POST straight to the commit route
        # with a confirmation, executed directly; the rest open the form in the
        # remote modal. The confirmation prefers the DSL-supplied one, falling
        # back to the action's own default ("<label>?" for immediate actions).
        def column_action_link_data(col_action, registered)
          data = {
            kanban_action: col_action.key.to_s,
            kanban_column: column.key.to_s
          }

          if registered.immediate
            data[:turbo_method] = :post
            confirmation = col_action.confirmation || registered.confirmation
            data[:turbo_confirm] = confirmation if confirmation.present?
          else
            data[:turbo_frame] = Plutonium::REMOTE_MODAL_FRAME
            data[:turbo_confirm] = col_action.confirmation if col_action.confirmation
          end

          data
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

        # Serialises the column's accepts policy for the data-kanban-accepts
        # attribute consumed by the Stimulus drag controller for drop hints.
        # The server remains the authority; this is display only.
        #
        # true  → "all"    (any source is accepted)
        # false → "none"   (no source is accepted)
        # Array → comma-joined list of accepted source column keys
        # Proc  → "all"    (per-card predicate; treated as permissive at the
        #                    column level — server evaluates per record)
        def accepts_value
          case column.accepts
          when true then "all"
          when false then "none"
          when Array then column.accepts.join(",")
          else "all"
          end
        end
      end
    end
  end
end

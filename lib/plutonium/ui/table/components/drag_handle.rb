# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # The drag affordance for a reorderable row.
        #
        # ## Why it lives inside the first cell rather than in a column of its own
        #
        # A dedicated grip column would cost horizontal space on EVERY row of
        # every reorderable table, forever, for a gesture used occasionally. So
        # the grip is pulled left into the first cell's padding with a negative
        # margin exactly equal to its own width: it occupies the padding the cell
        # already had, and the cell's content does not shift by a pixel — with or
        # without the grip, hovered or not.
        #
        # (The padding, not a negative offset outside the cell: the body cell is
        # `overflow-hidden`, which clips at the PADDING box. Anything positioned
        # beyond it would simply be invisible.)
        #
        # ## Why the grip is draggable and the <tr> is not
        #
        # See positioned_controller.js — `draggable="true"` kills text selection
        # inside the element, and a draggable row fights row_click_controller.
        # Both would be silent regressions on an ordinary data table.
        #
        # ## The disabled state IS the way out of the disabled state
        #
        # Dropping between two rows only means something when the visual order is
        # the stored order, so the server rejects a drop made under any other sort
        # (including a DESCENDING position sort). Rather than hiding the
        # affordance — which would leave the user with no hint that the table is
        # reorderable at all, and no way to make it so — it renders as a link that
        # applies the ascending position sort. That is precisely why `position_on`
        # registers `sort <attribute>`.
        class DragHandle < Phlexi::Table::HTML
          # @param sort_url [String, nil] nil when dragging is live; otherwise the
          #   URL that puts the collection back into ascending position order.
          def initialize(sort_url: nil)
            @sort_url = sort_url
          end

          def view_template
            @sort_url ? render_disabled : render_grip
          end

          private

          def render_grip
            button(
              type: "button",
              draggable: "true",
              class: themed(:drag_handle),
              title: "Drag to reorder",
              aria: {label: "Drag to reorder. Use the up and down arrow keys to move this row."},
              data: {positioned_grip: ""}
            ) { icon }
          end

          def render_disabled
            a(
              href: @sort_url,
              class: themed(:drag_handle_disabled),
              title: "Sort by position to reorder"
            ) { icon }
          end

          def icon
            render Phlex::TablerIcons::GripVertical.new(class: "w-4 h-4")
          end

          # A first-column cell with a grip in front of it.
          #
          # The table renders whatever the column's own block returned; this
          # wraps that component rather than replacing it, so a formatter, a
          # custom block or an inferred display component all keep rendering
          # exactly as they did. Flex rather than inline flow because that inner
          # component may be block or inline depending on the field type, and the
          # grip must sit beside it either way.
          #
          # Nested inside DragHandle so referencing it loads this file — a
          # sibling top-level class in drag_handle.rb would be invisible to
          # Zeitwerk until something happened to touch DragHandle first.
          class Cell < Phlexi::Table::HTML
            def initialize(cell, sort_url: nil)
              @cell = cell
              @sort_url = sort_url
            end

            def view_template
              div(class: themed(:drag_handle_cell)) do
                render DragHandle.new(sort_url: @sort_url)
                div(class: "min-w-0") { render @cell }
              end
            end
          end
        end
      end
    end
  end
end

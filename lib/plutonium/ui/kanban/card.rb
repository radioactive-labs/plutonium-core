# frozen_string_literal: true

module Plutonium
  module UI
    module Kanban
      # Thin wrapper around Grid::Card that makes the card draggable.
      #
      # Emits a draggable container div carrying:
      #   data-kanban-record-id — the record's id, consumed by the Stimulus
      #                           drag controller (Task 11) to identify the card
      #   data-kanban-column-key — the source column key, used by the move
      #                            handler (Task 7) to determine which column
      #                            the card came from
      #
      # All actual card rendering (image, header, meta, actions dropdown) is
      # delegated to Plutonium::UI::Grid::Card which already handles slots,
      # policy-gated actions, and the row-click controller.
      class Card < Plutonium::UI::Component::Base
        attr_reader :record, :column_key, :resource_definition, :resource_fields, :card_fields

        def initialize(record, column_key:, resource_definition:, resource_fields:, card_fields: nil, show_turbo_frame: "_top")
          @record = record
          @column_key = column_key
          @resource_definition = resource_definition
          @resource_fields = resource_fields
          # Optional slot-layout override from the board's card_fields declaration.
          # Threaded through to Grid::Card so it takes precedence over the
          # resource definition's grid_fields.  nil means use the definition.
          @card_fields = card_fields
          # The turbo-frame the card's show link targets — the remote-modal frame
          # (board show_in :modal) or "_top" (show_in :page). Either escapes the
          # column's lazy frame. Defaults to "_top".
          @show_turbo_frame = show_turbo_frame
        end

        def view_template
          div(
            draggable: "true",
            data: {
              kanban_record_id: record.id,
              kanban_column_key: column_key.to_s
            }
          ) do
            render_grid_card
          end
        end

        private

        # Extracted so tests can stub render_grid_card without needing a full
        # view_context (Grid::Card calls policy_for, route_options_to_url, etc.).
        def render_grid_card
          render Plutonium::UI::Grid::Card.new(
            record,
            resource_definition: resource_definition,
            resource_fields: resource_fields,
            card_fields: @card_fields,
            # Escape the column's lazy turbo-frame: either "_top" (full page) or
            # the document-wide remote-modal frame, both of which resolve outside
            # the kanban-col-<key> frame. Grid::Card keys the metadata-rail hiding
            # off this frame — the modal frame here means a kanban card's modal.
            show_turbo_frame: @show_turbo_frame
          )
        end
      end
    end
  end
end

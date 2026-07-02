# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      # The drop-interaction form used by the kanban card-drop modal.
      #
      # Behaves exactly like a standard interaction form (same fields, same
      # namespacing under `interaction[...]`, same submit button) with two
      # deliberate differences:
      #
      #   1. It POSTs to the record's `kanban_move` member route rather than the
      #      interaction's own commit URL, so Task 4's atomic handler runs the
      #      interaction AND repositions the card in one request.
      #   2. It carries the move context (from_column/to_column/to_index) as
      #      top-level hidden fields so the move handler knows where the card
      #      came from and where it landed.
      class KanbanMove < Interaction
        private

        # POST to <member>/kanban_move for the dropped record.
        def form_action
          resource_url_for(resource_record!, action: :kanban_move)
        end

        def form_template
          render_kanban_move_context
          super
        end

        # Emit the move context as top-level params (NOT namespaced under
        # interaction[...]) — the move handler reads params[:from_column] etc.
        # Values come from the GET request's query string.
        def render_kanban_move_context
          {
            from_column: params[:from_column],
            to_column: params[:to_column],
            to_index: params[:to_index]
          }.each do |name, value|
            input(type: :hidden, name: name.to_s, value: value)
          end
        end
      end
    end
  end
end

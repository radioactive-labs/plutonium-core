# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      # Modal page shown when a card is dropped into a column that declares a
      # `enter_interaction:`. It reuses the interactive-action modal chrome
      # (title/description/modal mode all come from the enter_interaction's
      # auto-registered record action) but renders a form that POSTs to the
      # `kanban_move` member route instead of the interaction's own commit URL,
      # carrying the move context (from_column/to_column/to_index) as hidden
      # fields alongside the interaction's own inputs.
      class KanbanMove < InteractiveAction
        private

        def interactive_action_form_partial = "kanban_move_action_form"
      end
    end
  end
end

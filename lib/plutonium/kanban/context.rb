# frozen_string_literal: true

require "delegate"

module Plutonium
  module Kanban
    # Evaluation scope for dynamic `columns do…end` blocks at request time.
    #
    # Delegates everything to the request's view_context so the block can call
    # current_user, current_scoped_entity, params, helpers, etc. directly —
    # exactly like Plutonium::Action::ConditionContext does for action conditions.
    class Context < SimpleDelegator
    end
  end
end

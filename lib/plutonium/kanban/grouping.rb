# frozen_string_literal: true

module Plutonium
  module Kanban
    # The two primitives every kanban rendering path shares: which columns a
    # board has, and how a column's scope narrows a relation.
    #
    # There is deliberately no `call` that groups a whole relation in one go.
    # One existed and had no callers: KanbanActions renders columns
    # independently — each is its own lazy turbo-frame with its own per_column
    # cap and count — so a whole-board grouper only ever duplicated that logic
    # while quietly counting and limiting every column on every request.
    module Grouping
      module_function

      # Resolves the column list from a board. For dynamic boards, evaluates
      # the columns_block against the context (which exposes current_user,
      # params, etc. via delegation to view_context).
      def resolve_columns(board, context)
        return board.columns unless board.dynamic?
        Array(context.instance_exec(&board.columns_block)).flatten
      end

      # Applies a column scope to a relation.
      #   Symbol → relation.public_send(sym)   (named scope)
      #   Proc   → relation.instance_exec(&scope) (inline lambda, e.g. -> { where(status: "todo") })
      #   nil    → relation unchanged
      def apply_scope(relation, scope)
        case scope
        when Symbol then relation.public_send(scope)
        when Proc then relation.instance_exec(&scope)
        when nil then relation
        else raise ArgumentError, "Unsupported column scope: #{scope.inspect} (expected Symbol, Proc, or nil)"
        end
      end
    end
  end
end

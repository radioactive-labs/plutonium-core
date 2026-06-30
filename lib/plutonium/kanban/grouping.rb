# frozen_string_literal: true

module Plutonium
  module Kanban
    # Groups an already-authorized, query-applied, UN-paginated relation into
    # ordered, per_column-capped column entries.
    module Grouping
      module_function

      # Returns [{column:, cards: [records], total: Integer}, ...] in column order.
      def call(board:, relation:, context:)
        columns = resolve_columns(board, context)
        pos = board.position_config
        columns.map do |col|
          scoped = apply_scope(relation, col.scope)
          ordered = pos.order(scoped)
          if board.per_column
            total = ordered.count
            cards = ordered.limit(board.per_column).to_a
          else
            cards = ordered.to_a
            total = cards.size
          end
          {column: col, cards: cards, total: total}
        end
      end

      # Resolves the column list from a board. For dynamic boards, evaluates
      # the columns_block against the context (which exposes current_user,
      # params, etc. via delegation to view_context). Public so Task 7 (move
      # handler) can call Grouping.resolve_columns(board, context) directly.
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

# frozen_string_literal: true

module Plutonium
  module Kanban
    class DSL
      def self.build(&block)
        dsl = new
        dsl.instance_eval(&block) if block
        dsl.to_board
      end

      def initialize
        @columns = []
        @columns_block = nil
        @card_fields = nil
        @per_column = nil
        @realtime = false
        @position_config = Positioning::Config.default
        @lazy = true
        @show_in = nil
      end

      def column(key, **opts, &blk)
        col = Column.new(key, **opts)
        col.instance_eval(&blk) if blk
        @columns << col
      end

      # Fluent DSL setters — `attr_writer` would change the call syntax
      # (`per_column 25` → `self.per_column = 25`), so keep them as methods.
      # standard:disable Style/TrivialAccessors
      def columns(&blk) = @columns_block = blk
      def card_fields(**slots) = @card_fields = slots
      def per_column(n) = @per_column = n
      def realtime(v = true) = @realtime = v
      def lazy(v = true) = @lazy = v
      # standard:enable Style/TrivialAccessors

      # Overrides where a card click opens the record's show page, for this
      # board only:
      #   :modal — open in a centered modal dialog
      #   :page  — navigate the whole page to the show route
      # When unset, the board inherits the definition's `show_in` (default :page).
      def show_in(mode) = @show_in = mode # standard:disable Style/TrivialAccessors

      def position_on(attr = :position, &blk)
        @position_config =
          if attr == false
            Positioning::Config.disabled
          elsif blk
            Positioning::Config.with_block(attr, blk)
          else
            Positioning::Config.attribute(attr)
          end
      end

      def to_board
        Board.new(
          columns: @columns,
          columns_block: @columns_block,
          card_fields: @card_fields,
          per_column: @per_column,
          realtime: @realtime,
          position_config: @position_config,
          lazy: @lazy,
          show_in: @show_in
        )
      end
    end
  end
end

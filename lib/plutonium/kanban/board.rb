# frozen_string_literal: true

module Plutonium
  module Kanban
    class Board
      attr_reader :columns, :columns_block, :card_fields, :per_column, :position_config, :lazy

      def initialize(columns:, columns_block:, card_fields:, per_column:, realtime:, position_config:, lazy:)
        @columns = columns
        @columns_block = columns_block
        @card_fields = card_fields
        @per_column = per_column
        @realtime = realtime
        @position_config = position_config
        @lazy = lazy
        freeze
      end

      def realtime? = !!@realtime
      def dynamic? = !@columns_block.nil?
    end
  end
end

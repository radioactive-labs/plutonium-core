# frozen_string_literal: true

module Plutonium
  module Kanban
    class Board
      attr_reader :columns, :columns_block, :card_fields, :per_column, :position_config, :show_in

      # nil means "inherit the definition's show_in"; the board only overrides
      # when explicitly set to :modal or :page.
      VALID_SHOW_IN = [nil, :modal, :page].freeze

      def initialize(columns:, columns_block:, card_fields:, per_column:, realtime:, position_config:, lazy:, show_in: nil)
        unless VALID_SHOW_IN.include?(show_in)
          raise ArgumentError, "show_in must be one of #{VALID_SHOW_IN.compact.inspect} (or unset), got #{show_in.inspect}"
        end

        @columns = columns
        @columns_block = columns_block
        @card_fields = card_fields
        @per_column = per_column
        @realtime = realtime
        @position_config = position_config
        @lazy = lazy
        @show_in = show_in
        @columns.each(&:freeze)
        @columns.freeze
        @card_fields&.freeze
        freeze
      end

      def realtime? = !!@realtime
      def lazy? = !!@lazy
      def dynamic? = !@columns_block.nil?

      # Resolves the board's effective show_in, falling back to the definition's
      # `show_in` when the board doesn't override it. Pass the resource definition.
      def show_in_for(definition) = @show_in || definition.show_in
    end
  end
end

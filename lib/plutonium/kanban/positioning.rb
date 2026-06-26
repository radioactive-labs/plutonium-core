# frozen_string_literal: true

require "plutonium/positioning"

module Plutonium
  module Kanban
    module Positioning
      # Value object passed to Mode B blocks, carrying the full drop context.
      Move = Data.define(:record, :column, :prev, :next, :index)

      # Strategy configuration object created by the `position_on` DSL.
      #
      # Three modes:
      #   Mode A (:delegate) — delegate reposition! to Plutonium::Positioning concern
      #   Mode B (:block)    — call a user-supplied block with a Move
      #   Mode C (:disabled) — no ordering; relation returned unchanged
      class Config
        # Mode A, default attribute :position
        def self.default
          new(:delegate, :position, nil)
        end

        # Mode A, custom attribute
        def self.attribute(attr)
          new(:delegate, attr.to_sym, nil)
        end

        # Mode B — orders by attr, write delegated to block
        def self.with_block(attr, block)
          new(:block, attr.to_sym, block)
        end

        # Mode C — disabled
        def self.disabled
          new(:disabled, nil, nil)
        end

        attr_reader :attribute

        def initialize(mode, attribute, block)
          @mode = mode
          @attribute = attribute
          @block = block
        end

        def disabled?
          @mode == :disabled
        end

        # Apply positional ordering to a relation.
        # Mode A/B: relation.reorder(attribute)
        # Mode C:   return relation unchanged
        def order(relation)
          return relation if disabled?
          relation.reorder(@attribute)
        end

        # Persist the new position for a dropped record.
        # Mode A: delegate to record.reposition!(prev_record:, next_record:)
        # Mode B: call the user block with a Move
        # Mode C: no-op
        def reposition!(record:, column:, prev_record:, next_record:, index:)
          case @mode
          when :delegate
            record.reposition!(prev_record:, next_record:)
          when :block
            @block.call(Move.new(record:, column:, prev: prev_record, next: next_record, index:))
          when :disabled
            nil
          end
        end
      end
    end
  end
end

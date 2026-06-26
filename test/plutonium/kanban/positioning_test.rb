# frozen_string_literal: true

require "test_helper"
require "plutonium/kanban/positioning"

module Plutonium
  module Kanban
    class PositioningTest < Minitest::Test
      # ------------------------------------------------------------------ #
      # Move value object                                                    #
      # ------------------------------------------------------------------ #

      def test_move_is_a_data_object_with_expected_members
        record = Object.new
        column = :todo
        move = Positioning::Move.new(record:, column:, prev: nil, next: nil, index: 0)
        assert_equal record, move.record
        assert_equal column, move.column
        assert_nil move.prev
        assert_nil move.next
        assert_equal 0, move.index
      end

      # ------------------------------------------------------------------ #
      # Positioning::Config.default — Mode A, attribute :position                         #
      # ------------------------------------------------------------------ #

      def test_default_attribute_is_position
        assert_equal :position, Positioning::Config.default.attribute
      end

      def test_default_is_not_disabled
        refute Positioning::Config.default.disabled?
      end

      # ------------------------------------------------------------------ #
      # Config.attribute — Mode A, custom attribute                          #
      # ------------------------------------------------------------------ #

      def test_attribute_factory_sets_attribute
        assert_equal :rank, Positioning::Config.attribute(:rank).attribute
      end

      def test_attribute_factory_is_not_disabled
        refute Positioning::Config.attribute(:rank).disabled?
      end

      # ------------------------------------------------------------------ #
      # Positioning::Config.disabled — Mode C                                             #
      # ------------------------------------------------------------------ #

      def test_disabled_is_disabled
        assert Positioning::Config.disabled.disabled?
      end

      def test_disabled_attribute_is_nil
        assert_nil Positioning::Config.disabled.attribute
      end

      def test_disabled_order_returns_relation_unchanged
        relation = Object.new
        result = Positioning::Config.disabled.order(relation)
        assert_same relation, result
      end

      def test_disabled_reposition_is_noop
        record = Object.new
        result = Positioning::Config.disabled.reposition!(record:, column: :todo, prev_record: nil, next_record: nil, index: 0)
        assert_nil result
      end

      # ------------------------------------------------------------------ #
      # Positioning::Config.default / Config.attribute — #order calls reorder            #
      # ------------------------------------------------------------------ #

      def test_mode_a_order_calls_reorder_with_attribute
        reordered_relation = Object.new
        relation = Struct.new(:reorder_args) do
          def reorder(*args)
            Struct.new(:captured) { }.new(args)
          end
        end.new

        # Use a plain spy relation
        spy = build_relation_spy
        Positioning::Config.default.order(spy)
        assert_equal [:position], spy.reorder_args
      end

      def test_mode_b_order_calls_reorder_with_attribute
        spy = build_relation_spy
        block = ->(move) {}
        Positioning::Config.with_block(:rank, block).order(spy)
        assert_equal [:rank], spy.reorder_args
      end

      # ------------------------------------------------------------------ #
      # Positioning::Config.default — Mode A reposition! delegates to record             #
      # ------------------------------------------------------------------ #

      def test_mode_a_reposition_delegates_to_record
        spy_record = build_reposition_spy
        prev = Object.new
        nxt = Object.new

        Positioning::Config.default.reposition!(record: spy_record, column: :todo, prev_record: prev, next_record: nxt, index: 2)

        assert spy_record.reposition_called?, "expected reposition! to be called on record"
        assert_same prev, spy_record.prev_record_received
        assert_same nxt, spy_record.next_record_received
      end

      # ------------------------------------------------------------------ #
      # Config.with_block — Mode B reposition! calls block with Move        #
      # ------------------------------------------------------------------ #

      def test_mode_b_reposition_calls_block_with_move
        received_move = nil
        call_count = 0
        block = ->(move) {
          call_count += 1
          received_move = move
        }

        record = Object.new
        column = :done
        prev = Object.new
        nxt = Object.new

        Positioning::Config.with_block(:rank, block).reposition!(
          record:, column:, prev_record: prev, next_record: nxt, index: 3
        )

        assert_equal 1, call_count, "block should be called exactly once"
        assert_instance_of Positioning::Move, received_move
        assert_same record, received_move.record
        assert_equal column, received_move.column
        assert_same prev, received_move.prev
        assert_same nxt, received_move.next
        assert_equal 3, received_move.index
      end

      private

      def build_relation_spy
        Class.new do
          attr_reader :reorder_args

          def reorder(*args)
            @reorder_args = args
            self
          end
        end.new
      end

      def build_reposition_spy
        Class.new do
          attr_reader :prev_record_received, :next_record_received

          def reposition!(prev_record:, next_record:)
            @reposition_called = true
            @prev_record_received = prev_record
            @next_record_received = next_record
          end

          def reposition_called?
            @reposition_called == true
          end
        end.new
      end
    end
  end
end

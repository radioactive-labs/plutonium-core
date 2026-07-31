# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Positioning
    class ConfigTest < Minitest::Test
      def test_kanban_namespace_still_resolves_to_the_promoted_class
        assert_same Plutonium::Positioning::Config, Plutonium::Kanban::Positioning::Config
        assert_same Plutonium::Positioning::Move, Plutonium::Kanban::Positioning::Move
      end

      def test_move_column_defaults_to_nil_off_board
        move = Plutonium::Positioning::Move.new(
          record: :rec, prev: nil, next: nil, index: 0
        )
        assert_nil move.column
      end

      def test_disabled_mode_leaves_the_relation_untouched
        relation = Object.new
        config = Plutonium::Positioning::Config.disabled
        assert config.disabled?
        assert_same relation, config.order(relation)
      end
    end
  end
end

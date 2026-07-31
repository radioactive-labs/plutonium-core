# frozen_string_literal: true

require "test_helper"
require "plutonium/positioning/config"

module Plutonium
  module Positioning
    class ConfigTest < Minitest::Test
      def test_kanban_namespace_still_resolves_to_the_promoted_class
        assert_same Plutonium::Positioning::Config, Plutonium::Kanban::Positioning::Config
        assert_same Plutonium::Positioning::Move, Plutonium::Kanban::Positioning::Move
      end

      # Off a board there is no column to report, so callers omit it entirely.
      def test_reposition_defaults_column_to_nil_off_board
        captured = nil
        config = Plutonium::Positioning::Config.with_block(:position, ->(move) { captured = move })
        config.reposition!(record: :rec, prev_record: nil, next_record: nil, index: 0)
        assert_nil captured.column
      end

      # config.rb must stay loadable on its own — see the comment at its top.
      def test_config_loads_standalone_without_the_model_concern
        lib = File.expand_path("../../../../lib", __dir__)
        out = `ruby -I#{lib} -e 'require "plutonium/positioning/config"; print defined?(Plutonium::Positioning::Model).inspect' 2>&1`
        assert_predicate $?, :success?
        assert_equal "nil", out
      end
    end
  end
end

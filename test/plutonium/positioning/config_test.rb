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

      # A Mode B block is an opaque write — the framework cannot know what it did,
      # and gems in this space routinely renumber the whole group (acts_as_list
      # does), so it always forces reconciliation.
      #
      # assert_equal true, not a bare assert: the block's own return value is
      # whatever the author's last expression happened to be (here :ignored), and
      # a truthiness assertion would pass on that by accident — proving only that
      # the block ran, not that reposition! reports the reconcile signal itself.
      def test_block_mode_always_reports_reconcile_needed
        config = Plutonium::Positioning::Config.with_block(:position, ->(_move) { :ignored })
        assert_equal true, config.reposition!(record: Object.new, prev_record: nil, next_record: nil, index: 0)
      end

      # Likewise assert_equal false rather than refute — nil is falsy, so a bare
      # refute would also pass on the old no-op return.
      def test_disabled_mode_never_reports_reconcile_needed
        config = Plutonium::Positioning::Config.disabled
        assert_equal false, config.reposition!(record: Object.new, prev_record: nil, next_record: nil, index: 0)
      end

      # config.rb must stay loadable on its own — see the comment at its top.
      #
      # with_unbundled_env is load-bearing, not tidiness: `bundle exec` exports
      # RUBYOPT=-rbundler/setup, which the backtick subshell inherits, putting
      # every Gemfile gem's lib on the child's $LOAD_PATH. Under that, the -I
      # below is decorative and the test would pass even if config.rb grew a
      # dependency on ActiveSupport — asserting nothing.
      def test_config_loads_standalone_without_the_model_concern
        lib = File.expand_path("../../../lib", __dir__)
        out = Bundler.with_unbundled_env do
          `ruby -I#{lib} -e 'require "plutonium/positioning/config"; print defined?(Plutonium::Positioning::Model).inspect' 2>&1`
        end
        assert_predicate $?, :success?
        assert_equal "nil", out
      end
    end
  end
end

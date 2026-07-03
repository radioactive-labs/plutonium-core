# frozen_string_literal: true

require "test_helper"
require "plutonium/kanban"

module Plutonium
  module Kanban
    class ColumnTest < Minitest::Test
      # A real Interaction subclass with a conventional "…Interaction" name so
      # #enter_interaction_key can be exercised against the demodulize/underscore
      # convention.
      class MarkLostInteraction < Plutonium::Resource::Interaction
        attribute :resource

        private

        def execute
          succeed(resource)
        end
      end

      # ------------------------------------------------------------------ #
      # enter_interaction — storage                                           #
      # ------------------------------------------------------------------ #

      def test_enter_interaction_defaults_to_nil
        col = Column.new(:lost)
        assert_nil col.enter_interaction
      end

      def test_enter_interaction_stores_the_class
        col = Column.new(:lost, enter_interaction: MarkLostInteraction)
        assert_equal MarkLostInteraction, col.enter_interaction
      end

      # ------------------------------------------------------------------ #
      # enter_interaction? — predicate                                        #
      # ------------------------------------------------------------------ #

      def test_enter_interaction_predicate_false_by_default
        refute Column.new(:lost).enter_interaction?
      end

      def test_enter_interaction_predicate_true_when_set
        assert Column.new(:lost, enter_interaction: MarkLostInteraction).enter_interaction?
      end

      # ------------------------------------------------------------------ #
      # enter_interaction_key — column-scoped internal routing key            #
      # ------------------------------------------------------------------ #

      def test_enter_interaction_key_is_column_scoped
        # Scoped to the column key (NOT the interaction class name), so it is
        # unique by construction — two columns reusing the same interaction class
        # can never collide.
        col = Column.new(:lost, enter_interaction: MarkLostInteraction)
        assert_equal :lost_enter_interaction, col.enter_interaction_key
      end

      def test_enter_interaction_key_is_nil_without_enter_interaction
        assert_nil Column.new(:lost).enter_interaction_key
      end

      # ------------------------------------------------------------------ #
      # enter_interaction — validation                                        #
      # ------------------------------------------------------------------ #

      def test_enter_interaction_rejects_non_interaction_string
        assert_raises(ArgumentError) do
          Column.new(:x, enter_interaction: "nope")
        end
      end

      def test_enter_interaction_rejects_non_interaction_class
        assert_raises(ArgumentError) do
          Column.new(:x, enter_interaction: String)
        end
      end

      # ------------------------------------------------------------------ #
      # on_exit — source-side callback storage                               #
      # ------------------------------------------------------------------ #

      def test_on_exit_defaults_to_nil
        assert_nil Column.new(:todo).on_exit
      end

      def test_on_exit_stores_the_callback_verbatim
        cb = ->(r) {}
        assert_same cb, Column.new(:todo, on_exit: cb).on_exit
      end

      def test_on_exit_stores_a_symbol
        assert_equal :archive!, Column.new(:todo, on_exit: :archive!).on_exit
      end

      # ------------------------------------------------------------------ #
      # on_drop: / drop_interaction: — deprecated, renamed aliases           #
      #                                                                      #
      # Dev/test raise so the rename is caught before release; deployed envs #
      # (production/staging) warn and map the old value so upgrades don't    #
      # break booting deployments.                                           #
      # ------------------------------------------------------------------ #

      def test_on_drop_raises_in_test_env
        err = assert_raises(ArgumentError) { Column.new(:todo, on_drop: :mark_done!) }
        assert_match(/on_drop.*renamed.*on_enter/, err.message)
      end

      def test_drop_interaction_raises_in_test_env
        err = assert_raises(ArgumentError) { Column.new(:lost, drop_interaction: MarkLostInteraction) }
        assert_match(/drop_interaction.*renamed.*enter_interaction/, err.message)
      end

      def test_on_drop_is_supported_and_mapped_in_production
        with_rails_env("production") do
          col = Column.new(:todo, on_drop: :mark_done!)
          assert_equal :mark_done!, col.on_enter, "on_drop: must map onto on_enter in production"
        end
      end

      def test_drop_interaction_is_supported_and_mapped_in_production
        with_rails_env("production") do
          col = Column.new(:lost, drop_interaction: MarkLostInteraction)
          assert_equal MarkLostInteraction, col.enter_interaction
          assert col.enter_interaction?, "drop_interaction: must map onto enter_interaction in production"
        end
      end

      def test_new_name_wins_when_both_given_in_production
        with_rails_env("production") do
          col = Column.new(:todo, on_drop: :old, on_enter: :new)
          assert_equal :new, col.on_enter, "the new on_enter: value must win over the deprecated on_drop:"
        end
      end

      private

      # Swap Rails.env for the duration of the block. Rails.env= builds a fresh
      # EnvironmentInquirer, so production?/development?/test? all reflect the
      # new value; restored in ensure.
      def with_rails_env(name)
        original = Rails.env
        Rails.env = name
        yield
      ensure
        Rails.env = original
      end
    end
  end
end

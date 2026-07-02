# frozen_string_literal: true

require "test_helper"
require "plutonium/kanban"

module Plutonium
  module Kanban
    class ColumnTest < Minitest::Test
      # A real Interaction subclass with a conventional "…Interaction" name so
      # #drop_interaction_key can be exercised against the demodulize/underscore
      # convention.
      class MarkLostInteraction < Plutonium::Resource::Interaction
        attribute :resource

        private

        def execute
          succeed(resource)
        end
      end

      # ------------------------------------------------------------------ #
      # drop_interaction — storage                                           #
      # ------------------------------------------------------------------ #

      def test_drop_interaction_defaults_to_nil
        col = Column.new(:lost)
        assert_nil col.drop_interaction
      end

      def test_drop_interaction_stores_the_class
        col = Column.new(:lost, drop_interaction: MarkLostInteraction)
        assert_equal MarkLostInteraction, col.drop_interaction
      end

      # ------------------------------------------------------------------ #
      # drop_interaction? — predicate                                        #
      # ------------------------------------------------------------------ #

      def test_drop_interaction_predicate_false_by_default
        refute Column.new(:lost).drop_interaction?
      end

      def test_drop_interaction_predicate_true_when_set
        assert Column.new(:lost, drop_interaction: MarkLostInteraction).drop_interaction?
      end

      # ------------------------------------------------------------------ #
      # drop_interaction_key — conventional action key derivation            #
      # ------------------------------------------------------------------ #

      def test_drop_interaction_key_derives_from_class_name
        col = Column.new(:lost, drop_interaction: MarkLostInteraction)
        assert_equal :mark_lost, col.drop_interaction_key
      end

      def test_drop_interaction_key_is_nil_without_drop_interaction
        assert_nil Column.new(:lost).drop_interaction_key
      end

      # ------------------------------------------------------------------ #
      # drop_interaction — validation                                        #
      # ------------------------------------------------------------------ #

      def test_drop_interaction_rejects_non_interaction_string
        assert_raises(ArgumentError) do
          Column.new(:x, drop_interaction: "nope")
        end
      end

      def test_drop_interaction_rejects_non_interaction_class
        assert_raises(ArgumentError) do
          Column.new(:x, drop_interaction: String)
        end
      end
    end
  end
end

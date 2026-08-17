# frozen_string_literal: true

require "test_helper"
require "plutonium/kanban"

module Plutonium
  module Kanban
    class GroupingTest < Minitest::Test
      # ------------------------------------------------------------------ #
      # Ad-hoc table + model for isolation                                   #
      # ------------------------------------------------------------------ #

      def setup
        ActiveRecord::Base.with_connection do |c|
          c.create_table(:grouping_test_cards, force: true) do |t|
            t.string :status
            t.decimal :position, precision: 20, scale: 10
            t.timestamps
          end
        end

        Object.const_set(:GroupingTestCard, Class.new(ActiveRecord::Base) do
          self.table_name = "grouping_test_cards"
          scope :todo, -> { where(status: "todo") }
          scope :done, -> { where(status: "done") }
        end)
      end

      def teardown
        Object.send(:remove_const, :GroupingTestCard) if Object.const_defined?(:GroupingTestCard)
        ActiveRecord::Base.with_connection do |c|
          c.drop_table(:grouping_test_cards, if_exists: true)
        end
      end

      # ------------------------------------------------------------------ #
      # Context — delegates to wrapped view_context                          #
      # ------------------------------------------------------------------ #

      def test_context_delegates_current_user
        view_ctx = Struct.new(:current_user).new("alice")
        ctx = Context.new(view_ctx)
        assert_equal "alice", ctx.current_user
      end

      def test_context_delegates_params
        view_ctx = Struct.new(:params).new({page: 1})
        ctx = Context.new(view_ctx)
        assert_equal({page: 1}, ctx.params)
      end

      def test_context_delegates_arbitrary_methods
        view_ctx = Struct.new(:current_scoped_entity).new("org-1")
        ctx = Context.new(view_ctx)
        assert_equal "org-1", ctx.current_scoped_entity
      end

      def test_context_wraps_object_directly_accessible
        view_ctx = Object.new
        ctx = Context.new(view_ctx)
        assert_same view_ctx, ctx.__getobj__
      end

      # ------------------------------------------------------------------ #
      # apply_scope — Symbol, Proc, nil, and anything else                   #
      # ------------------------------------------------------------------ #

      def test_symbol_scope_dispatches_to_the_named_scope
        GroupingTestCard.create!(status: "todo", position: 1)
        GroupingTestCard.create!(status: "done", position: 2)

        scoped = Grouping.apply_scope(GroupingTestCard.all, :todo)
        assert_equal ["todo"], scoped.map(&:status)
      end

      def test_proc_scope_runs_against_the_relation
        GroupingTestCard.create!(status: "todo", position: 1)
        GroupingTestCard.create!(status: "done", position: 2)

        scoped = Grouping.apply_scope(GroupingTestCard.all, -> { where(status: "todo") })
        assert_equal ["todo"], scoped.map(&:status)
      end

      def test_nil_scope_returns_the_relation_unchanged
        relation = GroupingTestCard.all
        assert_same relation, Grouping.apply_scope(relation, nil)
      end

      def test_unsupported_scope_type_raises_argument_error
        error = assert_raises(ArgumentError) do
          Grouping.apply_scope(GroupingTestCard.all, 42)
        end
        assert_match(/Unsupported column scope/, error.message)
      end

      # ------------------------------------------------------------------ #
      # Positioning::Config#order — reorder beats any prior ordering         #
      # ------------------------------------------------------------------ #

      # A column scope (or the caller's own relation) may already carry an
      # ORDER BY; positional ordering must win, which is why Config uses
      # `reorder` rather than `order`.
      def test_position_ordering_overrides_a_prior_ordering
        GroupingTestCard.create!(status: "todo", position: 3)
        GroupingTestCard.create!(status: "todo", position: 1)
        GroupingTestCard.create!(status: "todo", position: 2)

        config = Plutonium::Positioning::Config.attribute(:position)
        ordered = config.order(GroupingTestCard.order(position: :desc))

        assert_equal [1, 2, 3], ordered.map { |c| c.position.to_i }
      end

      def test_disabled_config_leaves_the_relation_alone
        relation = GroupingTestCard.order(position: :desc)
        assert_same relation, Plutonium::Positioning::Config.disabled.order(relation)
      end

      # ------------------------------------------------------------------ #
      # Dynamic columns — block evaluated against Context                    #
      # ------------------------------------------------------------------ #

      def test_resolve_columns_returns_static_columns_when_not_dynamic
        board = DSL.build do
          column :todo
          column :done
        end

        columns = Grouping.resolve_columns(board, dummy_context)
        assert_equal %i[todo done], columns.map(&:key)
      end

      def test_resolve_columns_evaluates_block_for_dynamic_board
        view_ctx = Struct.new(:flag).new(true)
        ctx = Context.new(view_ctx)

        board = DSL.build do
          columns do
            flag ? [Plutonium::Kanban::Column.new(:active)] : []
          end
        end

        columns = Grouping.resolve_columns(board, ctx)
        assert_equal 1, columns.size
        assert_equal :active, columns.first.key
      end

      private

      def dummy_context
        Context.new(Object.new)
      end
    end
  end
end

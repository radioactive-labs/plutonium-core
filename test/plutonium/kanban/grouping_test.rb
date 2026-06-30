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
      # Grouping.call — basic column grouping                                #
      # ------------------------------------------------------------------ #

      def test_grouping_returns_one_entry_per_column
        board = DSL.build do
          column :todo, scope: :todo
          column :done, scope: :done
        end

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal 2, result.size
      end

      def test_grouping_preserves_column_order
        board = DSL.build do
          column :todo, scope: :todo
          column :done, scope: :done
        end

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal :todo, result[0][:column].key
        assert_equal :done, result[1][:column].key
      end

      def test_grouping_result_has_expected_keys
        board = DSL.build { column :todo, scope: :todo }
        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        entry = result.first
        assert entry.key?(:column)
        assert entry.key?(:cards)
        assert entry.key?(:total)
      end

      # ------------------------------------------------------------------ #
      # Scope types — Proc and Symbol                                        #
      # ------------------------------------------------------------------ #

      def test_symbol_scope_filters_by_named_scope
        GroupingTestCard.create!(status: "todo", position: 1)
        GroupingTestCard.create!(status: "done", position: 2)

        board = DSL.build do
          column :todo, scope: :todo
          column :done, scope: :done
        end

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal 1, result[0][:total]
        assert_equal "todo", result[0][:cards].first.status
        assert_equal 1, result[1][:total]
        assert_equal "done", result[1][:cards].first.status
      end

      def test_proc_scope_runs_against_relation
        GroupingTestCard.create!(status: "todo", position: 1)
        GroupingTestCard.create!(status: "done", position: 2)

        todo_scope = -> { where(status: "todo") }
        board = DSL.build { column :todo, scope: todo_scope }

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal 1, result[0][:total]
        assert_equal "todo", result[0][:cards].first.status
      end

      def test_nil_scope_returns_all_records
        GroupingTestCard.create!(status: "todo", position: 1)
        GroupingTestCard.create!(status: "done", position: 2)

        board = DSL.build { column :all }  # no scope

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal 2, result[0][:total]
      end

      def test_unsupported_scope_type_raises_argument_error
        board = DSL.build { column :bad, scope: 42 }

        error = assert_raises(ArgumentError) do
          Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        end
        assert_match(/Unsupported column scope/, error.message)
      end

      # ------------------------------------------------------------------ #
      # Ordering — position overrides any prior ordering (uses reorder)      #
      # ------------------------------------------------------------------ #

      def test_cards_ordered_by_position_ascending_overriding_prior_ordering
        # Insert in reverse position order to confirm reorder works
        GroupingTestCard.create!(status: "todo", position: 3)
        GroupingTestCard.create!(status: "todo", position: 1)
        GroupingTestCard.create!(status: "todo", position: 2)

        board = DSL.build do
          column :todo, scope: :todo
          position_on :position
        end

        # Deliberately start with a descending order to prove reorder overrides it
        relation = GroupingTestCard.order(position: :desc)
        result = Grouping.call(board: board, relation: relation, context: dummy_context)
        positions = result[0][:cards].map(&:position).map(&:to_i)
        assert_equal [1, 2, 3], positions
      end

      # ------------------------------------------------------------------ #
      # per_column — caps cards, total reflects full count                   #
      # ------------------------------------------------------------------ #

      def test_per_column_caps_cards_length
        5.times { |i| GroupingTestCard.create!(status: "todo", position: i + 1) }

        board = DSL.build do
          column :todo, scope: :todo
          per_column 2
        end

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal 2, result[0][:cards].size
      end

      def test_per_column_total_reports_full_count
        5.times { |i| GroupingTestCard.create!(status: "todo", position: i + 1) }

        board = DSL.build do
          column :todo, scope: :todo
          per_column 2
        end

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal 5, result[0][:total]
      end

      def test_no_per_column_returns_all_cards
        5.times { |i| GroupingTestCard.create!(status: "todo", position: i + 1) }

        board = DSL.build { column :todo, scope: :todo }

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: dummy_context)
        assert_equal 5, result[0][:cards].size
        assert_equal 5, result[0][:total]
      end

      # ------------------------------------------------------------------ #
      # Dynamic columns — block evaluated against Context                    #
      # ------------------------------------------------------------------ #

      def test_dynamic_columns_built_from_context
        GroupingTestCard.create!(status: "todo", position: 1)

        # Context exposes a list of statuses that the block uses to build columns
        view_ctx = Struct.new(:available_statuses).new(%w[todo done])
        ctx = Context.new(view_ctx)

        board = DSL.build do
          columns do
            available_statuses.map do |s|
              Plutonium::Kanban::Column.new(s, scope: -> { where(status: s) })
            end
          end
        end

        result = Grouping.call(board: board, relation: GroupingTestCard.all, context: ctx)
        assert_equal 2, result.size
        assert_equal :todo, result[0][:column].key
        assert_equal :done, result[1][:column].key
        assert_equal 1, result[0][:total]
        assert_equal 0, result[1][:total]
      end

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

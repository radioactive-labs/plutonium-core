# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Plutonium
  module Positioning
    # Regression guard: rebalancing must be ATOMIC on a model that lives on a
    # SECONDARY database.
    #
    # A transaction is opened on the RECEIVER's connection pool.
    # `ActiveRecord::Base.transaction` therefore BEGINs on primary, while
    # `row.update_column` issues its UPDATE on the model's OWN pool
    # (update_column -> update_columns -> self.class._update_record). On a
    # single-database app those are the same connection and the old code worked
    # by accident. Put the model on a secondary database and the BEGIN protects
    # nothing: every renumbering UPDATE autocommits on its own, so a failure
    # partway through leaves the group half-renumbered — duplicate or gapped
    # positions with nothing to roll back — while the empty transaction on
    # primary commits happily.
    #
    # The tests below are deliberately BEHAVIOURAL: they blow up in the middle of
    # a rebalance and assert that NOTHING was renumbered. They assert nothing
    # about which connection a transaction was opened on, so they survive any
    # reshaping of the implementation that keeps the guarantee.
    class SecondaryDatabaseTest < Minitest::Test
      # Raised from the update_column seam to abort a rebalance mid-flight.
      class Boom < StandardError; end

      # A second SQLite file with its own connection pool, standing in for a host
      # app whose model is on a secondary database via `connects_to`. Declared
      # with a config hash rather than a database.yml key on purpose: it needs no
      # change to test/dummy (which the generator tests `git clean`) and it
      # exercises the same thing connects_to ultimately produces — a model whose
      # pool is not ActiveRecord::Base's.
      class SecondaryBase < ActiveRecord::Base
        self.abstract_class = true

        DATABASE_PATH = File.join(Dir.tmpdir, "plutonium_positioning_secondary_test.sqlite3")

        establish_connection(adapter: "sqlite3", database: DATABASE_PATH)
      end

      class SecondaryItem < SecondaryBase
        self.table_name = "secondary_positioning_items"
        include Plutonium::Positioning::Model

        positioned_on :position, scope: :status

        # Test seam. With +fail_update_column_at+ set to N, the Nth update_column
        # on this model raises — the cheapest way to die halfway through a
        # rebalance loop with some rows already written.
        class << self
          attr_accessor :fail_update_column_at, :update_column_calls
        end

        def update_column(*)
          self.class.update_column_calls += 1
          raise Boom if self.class.update_column_calls == self.class.fail_update_column_at
          super
        end
      end

      def setup
        SecondaryItem.fail_update_column_at = nil
        SecondaryItem.update_column_calls = 0
        SecondaryItem.with_connection do |c|
          c.create_table(:secondary_positioning_items, force: true) do |t|
            t.string :status
            t.decimal :position, precision: 20, scale: 10
            t.timestamps
          end
        end
      end

      def teardown
        SecondaryItem.fail_update_column_at = nil
        SecondaryItem.with_connection do |c|
          c.drop_table(:secondary_positioning_items, if_exists: true)
        end
      end

      # Sanity check for the harness itself: if these two ever shared a pool the
      # atomicity tests below would pass vacuously.
      def test_the_model_really_is_on_a_separate_connection_pool
        refute_equal ActiveRecord::Base.connection_pool.object_id,
          SecondaryItem.connection_pool.object_id,
          "harness is broken: the secondary model shares primary's pool"
      end

      # ---------------------------------------------------------------- #
      # backfill_positions! (class method)                                #
      # ---------------------------------------------------------------- #

      def test_a_failed_backfill_renumbers_nothing_on_a_secondary_database
        t0 = Time.current
        10.times { |i| SecondaryItem.create!(status: "todo", position: 99.0, created_at: t0 + i) }
        before = SecondaryItem.order(:id).pluck(:id, :position)

        fail_at_update_column(4)

        assert_raises(Boom) { SecondaryItem.backfill_positions!(order: :created_at) }

        assert_equal before, SecondaryItem.order(:id).pluck(:id, :position),
          "a backfill that failed partway must roll back every row it renumbered"
      end

      # ---------------------------------------------------------------- #
      # rebalance_scope_group! (instance, driven through reposition!)     #
      # ---------------------------------------------------------------- #

      def test_a_failed_rebalance_renumbers_nothing_on_a_secondary_database
        rows = 10.times.map { |i| SecondaryItem.create!(status: "todo", position: (i + 1) * 10.0) }

        # Collapse the gap between the first two rows so reposition! is forced
        # down the rebalance path rather than simply splitting the interval.
        tiny = Plutonium::Positioning::EPSILON / 10
        rows[0].update_column(:position, 1.0)
        rows[1].update_column(:position, 1.0 + tiny)
        before = SecondaryItem.order(:id).pluck(:id, :position)

        mover = rows.last
        fail_at_update_column(4)

        assert_raises(Boom) do
          mover.reposition!(prev_record: rows[0].reload, next_record: rows[1].reload)
        end

        assert_equal before, SecondaryItem.order(:id).pluck(:id, :position),
          "a rebalance that failed partway must leave every position untouched"
      end

      # Rows in OTHER scope groups are not part of the rebalanced group, so they
      # must survive either way — this pins down that the rollback doesn't
      # overreach and undo unrelated work.
      def test_a_failed_rebalance_leaves_other_scope_groups_alone
        10.times { |i| SecondaryItem.create!(status: "todo", position: (i + 1) * 10.0) }
        other = SecondaryItem.create!(status: "done", position: 7.0)

        todo = SecondaryItem.where(status: "todo").order(:position).to_a
        tiny = Plutonium::Positioning::EPSILON / 10
        todo[0].update_column(:position, 1.0)
        todo[1].update_column(:position, 1.0 + tiny)

        fail_at_update_column(4)

        assert_raises(Boom) do
          todo.last.reposition!(prev_record: todo[0].reload, next_record: todo[1].reload)
        end

        assert_equal 7.0, other.reload.position.to_f
      end

      private

      # Arm the seam so the next +n+ th update_column raises. Resets the counter
      # so the fixture setup above (which itself calls update_column) doesn't
      # count toward it.
      def fail_at_update_column(n)
        SecondaryItem.update_column_calls = 0
        SecondaryItem.fail_update_column_at = n
      end
    end
  end
end

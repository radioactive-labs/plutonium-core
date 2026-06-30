# frozen_string_literal: true

require "test_helper"

module Plutonium
  class PositioningTest < Minitest::Test
    # ------------------------------------------------------------------ #
    # Setup / teardown — ad-hoc SQLite table, no dummy-app model needed   #
    # ------------------------------------------------------------------ #

    def setup
      ActiveRecord::Base.with_connection do |c|
        c.create_table(:positioning_test_items, force: true) do |t|
          t.string :status
          t.decimal :position, precision: 20, scale: 10
          t.timestamps
        end
      end

      @item_class = Class.new(ActiveRecord::Base) do
        self.table_name = "positioning_test_items"
        include Plutonium::Positioning

        positioned_on :position, scope: :status
      end
    end

    def teardown
      ActiveRecord::Base.with_connection do |c|
        c.drop_table(:positioning_test_items, if_exists: true)
      end
    end

    # ------------------------------------------------------------------ #
    # Pure math — no database                                              #
    # ------------------------------------------------------------------ #

    def test_position_between_both_nil_returns_zero
      assert_equal 0.0, Plutonium::Positioning.position_between(nil, nil)
    end

    def test_position_between_prev_nil_returns_next_minus_one
      assert_equal 4.0, Plutonium::Positioning.position_between(nil, 5.0)
    end

    def test_position_between_next_nil_returns_prev_plus_one
      assert_equal 4.0, Plutonium::Positioning.position_between(3.0, nil)
    end

    def test_position_between_both_present_returns_midpoint
      assert_equal 2.0, Plutonium::Positioning.position_between(1.0, 3.0)
    end

    def test_gap_exhausted_returns_false_when_either_nil
      refute Plutonium::Positioning.gap_exhausted?(nil, 5.0)
      refute Plutonium::Positioning.gap_exhausted?(1.0, nil)
      refute Plutonium::Positioning.gap_exhausted?(nil, nil)
    end

    def test_gap_exhausted_returns_false_when_gap_is_large
      refute Plutonium::Positioning.gap_exhausted?(1.0, 2.0)
    end

    def test_gap_exhausted_returns_true_when_gap_is_below_epsilon
      tiny = Plutonium::Positioning::EPSILON / 2
      assert Plutonium::Positioning.gap_exhausted?(1.0, 1.0 + tiny)
    end

    def test_gap_exhausted_returns_false_when_gap_equals_epsilon
      # gap must be STRICTLY less than EPSILON to be exhausted
      refute Plutonium::Positioning.gap_exhausted?(0.0, Plutonium::Positioning::EPSILON)
    end

    # ------------------------------------------------------------------ #
    # DB-backed: create assigns position at end of scope group            #
    # ------------------------------------------------------------------ #

    def test_create_assigns_position_starting_at_one_for_new_scope
      item = @item_class.create!(status: "todo")
      assert_equal 1.0, item.position.to_f
    end

    def test_create_appends_to_end_of_same_scope_group
      @item_class.create!(status: "todo")
      item2 = @item_class.create!(status: "todo")
      assert_equal 2.0, item2.position.to_f
    end

    def test_create_scope_groups_are_independent
      @item_class.create!(status: "todo")
      @item_class.create!(status: "todo")
      done_item = @item_class.create!(status: "done")
      assert_equal 1.0, done_item.position.to_f
    end

    def test_create_respects_existing_position_when_set
      item = @item_class.create!(status: "todo", position: 99.0)
      assert_equal 99.0, item.position.to_f
    end

    # ------------------------------------------------------------------ #
    # DB-backed: reposition! places a row between two neighbors           #
    # ------------------------------------------------------------------ #

    def test_reposition_places_item_between_two_neighbors
      a = @item_class.create!(status: "todo") # position 1.0
      b = @item_class.create!(status: "todo") # position 2.0
      c = @item_class.create!(status: "todo") # position 3.0

      # Move b out of the way first so the assertion proves real movement,
      # not just that b happened to already sit at the midpoint of a and c.
      b.update_column(:position, 99.0)

      b.reposition!(prev_record: a, next_record: c)

      assert b.reload.position.to_f > a.position.to_f, "b should land after a"
      assert b.position.to_f < c.position.to_f, "b should land before c"
    end

    def test_reposition_to_front_with_nil_prev
      a = @item_class.create!(status: "todo") # position 1.0
      b = @item_class.create!(status: "todo") # position 2.0

      b.reposition!(prev_record: nil, next_record: a)
      assert b.reload.position.to_f < a.reload.position.to_f,
        "b should have a lower position than a after moving to front"
    end

    def test_reposition_to_back_with_nil_next
      a = @item_class.create!(status: "todo") # position 1.0
      b = @item_class.create!(status: "todo") # position 2.0

      a.reposition!(prev_record: b, next_record: nil)
      assert a.reload.position.to_f > b.reload.position.to_f,
        "a should have a higher position than b after moving to back"
    end

    # ------------------------------------------------------------------ #
    # DB-backed: exhausted gap triggers rebalance and order is preserved  #
    # ------------------------------------------------------------------ #

    def test_reposition_rebalances_when_gap_exhausted
      a = @item_class.create!(status: "todo", position: 1.0)
      b = @item_class.create!(status: "todo", position: 2.0)
      c = @item_class.create!(status: "todo", position: 3.0)

      # Force an exhausted gap between a and c by jamming their positions together
      tiny = Plutonium::Positioning::EPSILON / 10
      a.update_column(:position, 1.0)
      c.update_column(:position, 1.0 + tiny)

      # b should still end up between a and c after rebalancing
      b.reposition!(prev_record: a, next_record: c)

      positions = [a, b, c].map { |r| r.reload.position.to_f }
      assert positions[0] < positions[1], "a should be before b"
      assert positions[1] < positions[2], "b should be before c"
    end

    # Natural exhaustion: repeatedly inserting into the SAME slot halves the
    # gap each time, so after ~20 inserts it drops below EPSILON and must
    # rebalance — without ever colliding or losing the drag order. The earlier
    # rebalance test jams positions artificially; this one drives the real path
    # through reposition! and proves rebalancing actually fires.
    def test_repeated_inserts_into_same_slot_rebalance_and_preserve_order
      # Count rebalances so we prove the exhaustion branch ran (rather than the
      # wide test column simply having room).
      rebalances = 0
      @item_class.prepend(Module.new do
        define_method(:rebalance_scope_group!) do
          rebalances += 1
          super()
        end
      end)

      first = @item_class.create!(status: "todo") # the fixed left anchor
      last = @item_class.create!(status: "todo") # the fixed right anchor

      inserted = []
      30.times do
        # Insert between the two left-most rows: `first` and whatever currently
        # sits second. Fetch fresh each pass so a rebalance (which renumbers via
        # update_column, leaving our in-memory objects stale) can't mislead us.
        left, right = @item_class.where(status: "todo").order(:position).limit(2).to_a
        x = @item_class.create!(status: "todo")
        x.reposition!(prev_record: left, next_record: right)
        inserted << x
      end

      assert rebalances >= 1,
        "30 insertions into the same slot must trigger at least one rebalance"

      rows = @item_class.where(status: "todo").order(:position).to_a
      positions = rows.map { |r| r.position.to_f }
      assert_equal positions.length, positions.uniq.length,
        "positions must stay distinct across rebalances"
      # Each new card lands just after `first`, so the order is:
      # first, newest … oldest, last.
      expected_ids = [first.id] + inserted.reverse.map(&:id) + [last.id]
      assert_equal expected_ids, rows.map(&:id),
        "drag order must survive rebalancing"
    end

    # A rebalance renumbers the WHOLE scope group, not just the two neighbors —
    # rows that weren't involved in the move must keep their relative order and
    # come out with clean, distinct positions.
    def test_rebalance_renumbers_whole_group_preserving_all_order
      a = @item_class.create!(status: "todo", position: 1.0)
      b = @item_class.create!(status: "todo", position: 2.0)
      c = @item_class.create!(status: "todo", position: 3.0)
      d = @item_class.create!(status: "todo", position: 4.0)
      e = @item_class.create!(status: "todo", position: 5.0)

      # Exhaust the gap between b and c.
      tiny = Plutonium::Positioning::EPSILON / 10
      b.update_column(:position, 2.0)
      c.update_column(:position, 2.0 + tiny)

      # Move e between b and c — triggers a full-group rebalance.
      e.reposition!(prev_record: b, next_record: c)

      rows = @item_class.where(status: "todo").order(:position).to_a
      positions = rows.map { |r| r.position.to_f }
      assert_equal positions.length, positions.uniq.length,
        "no duplicate positions after rebalance"
      # a and d were not neighbors of the move; they must keep their order, and
      # e must land between b and c.
      assert_equal [a.id, b.id, e.id, c.id, d.id], rows.map(&:id),
        "rebalance must preserve every row's order, with e inserted between b and c"
    end

    # Identical neighbor positions (gap == 0) are an exhausted gap: reposition!
    # must rebalance to break the tie rather than crash or write a duplicate.
    def test_rebalance_resolves_identical_neighbor_positions
      a = @item_class.create!(status: "todo")
      b = @item_class.create!(status: "todo")
      a.update_column(:position, 1.0)
      b.update_column(:position, 1.0) # exact tie
      c = @item_class.create!(status: "todo")

      c.reposition!(prev_record: a, next_record: b)

      positions = [a, b, c].map { |r| r.reload.position.to_f }
      assert_equal 3, positions.uniq.length,
        "the tie must be resolved into three distinct positions"
      # c lands strictly between its (post-rebalance) neighbors, whichever order
      # the tie resolved to.
      lo, hi = [a.position.to_f, b.position.to_f].minmax
      assert c.position.to_f > lo && c.position.to_f < hi,
        "c should sit strictly between a and b"
    end

    # ------------------------------------------------------------------ #
    # Migration helper: t.position                                         #
    # ------------------------------------------------------------------ #

    def test_position_migration_helper_creates_a_tuned_decimal_column
      ActiveRecord::Base.with_connection do |c|
        c.create_table(:positioning_helper_create, force: true) do |t|
          t.position
          t.position :sort_order
        end
        cols = c.columns(:positioning_helper_create).index_by(&:name)

        pos = cols.fetch("position")
        assert_equal :decimal, pos.type
        assert_equal 16, pos.precision
        assert_equal 8, pos.scale

        assert cols.key?("sort_order"), "a custom-named position column should be created"
        assert_equal 8, cols.fetch("sort_order").scale
      ensure
        c.drop_table(:positioning_helper_create, if_exists: true)
      end
    end

    def test_position_migration_helper_allows_overrides
      ActiveRecord::Base.with_connection do |c|
        c.create_table(:positioning_helper_override, force: true) do |t|
          t.position :position, scale: 10, precision: 20
        end
        pos = c.columns(:positioning_helper_override).find { |col| col.name == "position" }
        assert_equal 10, pos.scale
        assert_equal 20, pos.precision
      ensure
        c.drop_table(:positioning_helper_override, if_exists: true)
      end
    end

    def test_position_migration_helper_works_in_change_table
      ActiveRecord::Base.with_connection do |c|
        c.create_table(:positioning_helper_alter, force: true) { |t| t.string :name }
        c.change_table(:positioning_helper_alter) { |t| t.position }
        pos = c.columns(:positioning_helper_alter).find { |col| col.name == "position" }
        assert pos, "change_table t.position should add the column"
        assert_equal :decimal, pos.type
        assert_equal 8, pos.scale
      ensure
        c.drop_table(:positioning_helper_alter, if_exists: true)
      end
    end

    # ------------------------------------------------------------------ #
    # DB-backed: backfill_positions! numbers per scope group              #
    # ------------------------------------------------------------------ #

    def test_backfill_assigns_sequential_positions_per_scope_group
      t0 = Time.current

      todo1 = @item_class.create!(status: "todo", created_at: t0)
      todo2 = @item_class.create!(status: "todo", created_at: t0 + 1)
      done1 = @item_class.create!(status: "done", created_at: t0)
      done2 = @item_class.create!(status: "done", created_at: t0 + 1)

      # Scramble positions so backfill has something to fix
      @item_class.update_all(position: 99.0)

      @item_class.backfill_positions!(order: :created_at)

      assert_equal 1.0, todo1.reload.position.to_f
      assert_equal 2.0, todo2.reload.position.to_f
      assert_equal 1.0, done1.reload.position.to_f
      assert_equal 2.0, done2.reload.position.to_f
    end

    def test_backfill_numbers_globally_when_no_scope
      ActiveRecord::Base.with_connection do |c|
        c.create_table(:positioning_test_globals, force: true) do |t|
          t.decimal :position, precision: 20, scale: 10
          t.timestamps
        end
      end

      global_class = Class.new(ActiveRecord::Base) do
        self.table_name = "positioning_test_globals"
        include Plutonium::Positioning

        positioned_on :position
      end

      t0 = Time.current
      first = global_class.create!(created_at: t0)
      second = global_class.create!(created_at: t0 + 1)
      third = global_class.create!(created_at: t0 + 2)

      # Scramble positions so backfill has something to fix
      global_class.update_all(position: 99.0)

      global_class.backfill_positions!(order: :created_at)

      assert_equal 1.0, first.reload.position.to_f
      assert_equal 2.0, second.reload.position.to_f
      assert_equal 3.0, third.reload.position.to_f
    ensure
      ActiveRecord::Base.with_connection do |c|
        c.drop_table(:positioning_test_globals, if_exists: true)
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

# Mode B against a REAL third-party positioning gem.
#
# position_actions_test.rb covers Mode B's plumbing with stub blocks (what the
# Move carries, that a block write always streams). This file covers the thing
# a stub cannot: whether the acts_as_list recipe published in
# docs/reference/resource/positioning.md and .claude/skills/plutonium-resource/SKILL.md
# actually lands rows where it claims to, driven through the real endpoint.
#
# The fixture is Chore — `acts_as_list scope: [:status]`, an INTEGER position,
# and deliberately NO Plutonium::Positioning::Model. Its definition carries the
# documented block. Nothing here stubs the write.
#
# The finding these tests encode: `move.index` is a claim about the VIEWPORT,
# while acts_as_list's `insert_at` addresses the whole scope group. So the
# obvious `insert_at(move.index + 1)` is right only on an unfiltered page 1, and
# wrong — spectacularly, by up to a full page — everywhere else. The documented
# recipe therefore anchors off the neighbours, and both halves of that claim are
# pinned below with exact numbers.
class Plutonium::Resource::Controllers::PositionActionsActsAsListTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html"
  COLLECTION_TARGET = 'target="pu-collection-chores"'

  # The naive form the docs used to publish as the primary example, kept here so
  # its failure modes are measured rather than asserted from reading the gem.
  # If someone reinstates it in the docs, these numbers are the counter-evidence.
  INDEX_BASED_BLOCK = lambda { |move|
    move.record.insert_at(move.index + 1)
  }

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    Chore.delete_all
  end

  teardown { Chore.delete_all }

  # ─── Helpers ───────────────────────────────────────────────────────────────

  # Chores are titled "Chore 01".."Chore NN" and, because acts_as_list appends
  # on create, start out at positions 1..N in that order.
  def seed(count)
    count.times.map { |i| Chore.create!(title: "Chore #{format("%02d", i + 1)}", status: "todo") }
  end

  def titles = Chore.where(status: "todo").order(:position).pluck(:title)

  def positions = Chore.where(status: "todo").order(:position).pluck(:position)

  def drop(record, prev_id:, next_id:, to_index:, query: nil)
    post "/admin/chores/#{record.id}/reposition#{query}",
      params: {prev_id: prev_id, next_id: next_id, to_index: to_index},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}
  end

  # Swaps ChoreDefinition's Mode B block for the duration of the test, exactly
  # as position_actions_test.rb swaps TaskDefinition's config.
  def with_block(block)
    original = ChoreDefinition.defined_position_config
    ChoreDefinition.defined_position_config =
      Plutonium::Positioning::Config.with_block(:position, block)
    yield
  ensure
    ChoreDefinition.defined_position_config = original
  end

  # acts_as_list's contract is a 1-based contiguous ranking. If a drop ever
  # leaves a gap or a tie, the list is corrupt regardless of the visible order.
  def assert_contiguous_from_one
    assert_equal (1..Chore.where(status: "todo").count).to_a, positions,
      "acts_as_list must leave the group ranked 1..N with no gaps or ties"
  end

  # ─── The documented recipe, unpaginated ────────────────────────────────────

  test "a drop in the middle of an unpaginated list lands between its neighbours" do
    rows = seed(5)

    # Drag Chore 05 (last) into the slot between Chore 01 and Chore 02.
    drop(rows[4], prev_id: rows[0].id, next_id: rows[1].id, to_index: 1)

    assert_response :ok
    assert_equal ["Chore 01", "Chore 05", "Chore 02", "Chore 03", "Chore 04"], titles
    assert_equal 2, rows[4].reload.position
    assert_contiguous_from_one
  end

  test "a drop at the top of an unpaginated list lands at rank 1" do
    rows = seed(5)

    drop(rows[4], prev_id: "", next_id: rows[0].id, to_index: 0)

    assert_response :ok
    assert_equal ["Chore 05", "Chore 01", "Chore 02", "Chore 03", "Chore 04"], titles
    assert_equal 1, rows[4].reload.position
    assert_contiguous_from_one
  end

  test "a drop at the bottom of an unpaginated list lands at rank N" do
    rows = seed(5)

    drop(rows[0], prev_id: rows[4].id, next_id: "", to_index: 4)

    assert_response :ok
    assert_equal ["Chore 02", "Chore 03", "Chore 04", "Chore 05", "Chore 01"], titles
    assert_equal 5, rows[0].reload.position
    assert_contiguous_from_one
  end

  test "dragging upward from the bottom is the mirror of dragging downward" do
    # The two branches of the documented block differ only in whether the record
    # currently sits above or below its new prev — both must be exercised, or
    # half the recipe is untested.
    rows = seed(5)

    # Downward: Chore 01 (rank 1) to just after Chore 04 (rank 4).
    drop(rows[0], prev_id: rows[3].id, next_id: rows[4].id, to_index: 3)
    assert_equal ["Chore 02", "Chore 03", "Chore 04", "Chore 01", "Chore 05"], titles

    # Upward: Chore 05 (now rank 5) to just after Chore 02 (now rank 1).
    drop(rows[4], prev_id: rows[1].id, next_id: rows[2].id, to_index: 1)
    assert_equal ["Chore 02", "Chore 05", "Chore 03", "Chore 04", "Chore 01"], titles
    assert_contiguous_from_one
  end

  # ─── Pagination: where the naive form breaks ───────────────────────────────

  test "a drop in the middle of page 2 lands between its neighbours" do
    # 25 rows at Pagy's default limit of 20 → page 2 holds ranks 21..25.
    rows = seed(25)

    # Drag Chore 25 (rank 25) between Chore 21 (rank 21) and Chore 22 (rank 22).
    # to_index is PAGE-relative: Chore 21 is the first row of page 2, so the
    # slot after it is index 1 — not index 21.
    drop(rows[24], prev_id: rows[20].id, next_id: rows[21].id, to_index: 1, query: "?page=2")

    assert_response :ok
    assert_equal 22, rows[24].reload.position,
      "the drop must be resolved against the whole group, not the page"
    assert_equal ["Chore 20", "Chore 21", "Chore 25", "Chore 22", "Chore 23", "Chore 24"],
      titles.last(6)
    assert_contiguous_from_one
  end

  test "a drop at the TOP of page 2 lands after the last row of page 1" do
    # The case a blank prev_id makes dangerous: "nothing above me" is true of the
    # viewport and false of the list. Mode A resolves the hidden boundary
    # neighbour server-side; Mode B is handed nil, so the block has to fall back
    # to `move.next` — which is what the documented recipe does.
    rows = seed(25)

    drop(rows[24], prev_id: "", next_id: rows[20].id, to_index: 0, query: "?page=2")

    assert_response :ok
    assert_equal 21, rows[24].reload.position,
      "a page-2 top drop must land at the head of page 2, not the head of the list"
    assert_equal ["Chore 20", "Chore 25", "Chore 21", "Chore 22", "Chore 23", "Chore 24"],
      titles.last(6)
    assert_contiguous_from_one
  end

  test "insert_at(move.index + 1) teleports a page-2 drop to the top of the list" do
    # The measurement behind the docs' warning. Same gesture as the page-2 middle
    # drop above; the naive block turns to_index 1 into insert_at(2), which is
    # rank 2 of the WHOLE list — Chore 25 jumps 20 slots onto page 1.
    rows = seed(25)

    with_block(INDEX_BASED_BLOCK) do
      drop(rows[24], prev_id: rows[20].id, next_id: rows[21].id, to_index: 1, query: "?page=2")
    end

    assert_response :ok
    assert_equal 2, rows[24].reload.position
    assert_equal ["Chore 01", "Chore 25", "Chore 02"], titles.first(3),
      "move.index is page-relative; insert_at is not"
  end

  test "insert_at(move.index + 1) sends a page-2 top drop to the head of the list" do
    rows = seed(25)

    with_block(INDEX_BASED_BLOCK) do
      drop(rows[24], prev_id: "", next_id: rows[20].id, to_index: 0, query: "?page=2")
    end

    assert_response :ok
    assert_equal 1, rows[24].reload.position,
      "to_index 0 on page 2 still means insert_at(1) — the top of the whole list"
    assert_equal "Chore 25", titles.first
  end

  # ─── Filtering: the same failure without pagination ────────────────────────

  test "a drop on a filtered list lands relative to the rows the filter hid" do
    # The filter shows only Chore 01 (rank 1) and Chore 10 (rank 10); ranks 2..9
    # are hidden. Dragging Chore 01 below Chore 10 is a two-row gesture over a
    # ten-row list.
    rows = seed(10)

    drop(rows[0], prev_id: rows[9].id, next_id: "", to_index: 1, query: "?q%5Bsearch%5D=1")

    assert_response :ok
    assert_equal 10, rows[0].reload.position,
      "the drop must land after the real Chore 10, not after the second visible row"
    assert_equal "Chore 01", titles.last
    assert_contiguous_from_one
  end

  test "a drop above the first visible row of a filtered list respects the hidden rows above it" do
    # The blank-prev case again, this time hidden by a filter rather than a page
    # boundary: the top VISIBLE row is rank 5, so "above it" is rank 5 — not 1.
    rows = seed(10)
    rows[4].update_column(:title, "Xylo five")
    rows[9].update_column(:title, "Xylo ten")

    drop(rows[9], prev_id: "", next_id: rows[4].id, to_index: 0, query: "?q%5Bsearch%5D=Xylo")

    assert_response :ok
    assert_equal 5, rows[9].reload.position,
      "the row must land immediately above the first VISIBLE row, not at the head of the list"
    assert_equal ["Chore 04", "Xylo ten", "Xylo five", "Chore 06"], titles[3..6]
    assert_contiguous_from_one
  end

  test "insert_at(move.index + 1) barely moves a filtered drop" do
    # The measurement behind the docs' warning, filter edition. Dragging Chore 01
    # to the bottom of a two-row filtered view yields to_index 1 → insert_at(2),
    # so it slides one rank and stays at the top of the real list.
    rows = seed(10)

    with_block(INDEX_BASED_BLOCK) do
      drop(rows[0], prev_id: rows[9].id, next_id: "", to_index: 1, query: "?q%5Bsearch%5D=1")
    end

    assert_response :ok
    assert_equal 2, rows[0].reload.position,
      "the user dropped it last; the naive block moved it one slot"
    assert_equal "Chore 10", titles.last
  end

  test "insert_at(move.index + 1) sends a filtered top drop to the head of the list" do
    rows = seed(10)
    rows[4].update_column(:title, "Xylo five")
    rows[9].update_column(:title, "Xylo ten")

    with_block(INDEX_BASED_BLOCK) do
      drop(rows[9], prev_id: "", next_id: rows[4].id, to_index: 0, query: "?q%5Bsearch%5D=Xylo")
    end

    assert_response :ok
    assert_equal 1, rows[9].reload.position,
      "the user dropped it above rank 5; the naive block sent it to rank 1"
    assert_equal "Xylo ten", titles.first
  end

  # ─── Mode B always reconciles ──────────────────────────────────────────────

  test "every acts_as_list drop answers a turbo-stream, never 204" do
    # acts_as_list renumbers neighbours on every move, so the client's optimistic
    # DOM is stale by definition. Mode B has no way to know that, which is why it
    # streams unconditionally — including for a drop that changed nothing else.
    rows = seed(3)

    drop(rows[2], prev_id: rows[0].id, next_id: rows[1].id, to_index: 1)

    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
    assert_includes response.body, COLLECTION_TARGET
    assert_includes response.body, "Chore 01"
  end

  test "a no-op drop still streams the collection back" do
    rows = seed(3)

    # Drop Chore 02 exactly where it already is.
    drop(rows[1], prev_id: rows[0].id, next_id: rows[2].id, to_index: 1)

    assert_response :ok
    assert_includes response.body, COLLECTION_TARGET
    assert_equal ["Chore 01", "Chore 02", "Chore 03"], titles
  end

  test "the streamed collection is the page the drop came from" do
    seed(25)
    rows = Chore.where(status: "todo").order(:position).to_a

    drop(rows[24], prev_id: rows[20].id, next_id: rows[21].id, to_index: 1, query: "?page=2")

    assert_response :ok
    assert_includes response.body, "Chore 25"
    refute_includes response.body, "Chore 01",
      "page 2 must come back as page 2, not as page 1"
  end

  # ─── Mode B keeps its own semantics ────────────────────────────────────────

  test "a drop under a foreign sort is NOT rejected server-side in Mode B" do
    # The 422 sort gate is Mode A only: the block owns its own notion of
    # neighbours, so only the client-side gate applies. Documented, and easy to
    # regress by dropping the config.delegate? guard in PositionActions.
    rows = seed(5)

    drop(rows[4],
      prev_id: rows[0].id, next_id: rows[1].id, to_index: 1,
      query: "?q%5Bsort_fields%5D%5B%5D=position&q%5Bsort_directions%5D%5Bposition%5D=DESC")

    assert_response :ok
    refute_includes response.body, "sorted by position"
    assert_equal 2, rows[4].reload.position, "the block still wrote"
  end

  test "a positioning group the block does not know about is left alone" do
    # acts_as_list scope: [:status] — "done" chores are a separate list, ranked
    # from 1 independently. Reordering "todo" must not renumber them.
    todo = seed(3)
    done = 2.times.map { |i| Chore.create!(title: "Done #{i + 1}", status: "done") }

    drop(todo[2], prev_id: todo[0].id, next_id: todo[1].id, to_index: 1)

    assert_response :ok
    assert_equal [1, 2], done.map { |c| c.reload.position }
    assert_equal [1, 2, 3], Chore.where(status: "todo").order(:position).pluck(:position)
  end

  # ─── The model is genuinely outside Plutonium's positioning ────────────────

  test "Chore is a Mode B resource with no framework positioning at all" do
    # Guards the fixture itself: if someone adds Plutonium::Positioning::Model to
    # Chore, every assertion above silently starts testing Mode A instead.
    refute Chore.include?(Plutonium::Positioning::Model),
      "the acts_as_list fixture must not also carry the framework's concern"
    refute_predicate ChoreDefinition.defined_position_config, :delegate?
    refute_predicate ChoreDefinition.defined_position_config, :disabled?
  end
end

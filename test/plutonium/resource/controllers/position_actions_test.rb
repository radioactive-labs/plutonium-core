# frozen_string_literal: true

require "test_helper"

# Integration tests for the reposition member action (Task 5).
#
# Route:   POST /admin/tasks/:id/reposition
# Params:  prev_id, next_id, to_index
# Formats: Turbo Stream (Accept: text/vnd.turbo-stream.html)
#
# The contract under test:
#   * a clean Mode A drop answers 204 with an EMPTY body — the client already
#     moved the row optimistically, so there is nothing to repaint
#   * the collection is streamed back only when the client's view is (or may
#     be) stale: a rebalance, an unresolved neighbour, a Mode B block write
#   * rejections (403 / 422) stream the collection so the row snaps back, plus
#     a toast — never an HTML error page morphed into the table
#   * a resource with no `position_on` (or Mode C) is a 404
#
# TaskDefinition declares `position_on` (Mode A, :position); the Task model
# declares `positioned_on :position, scope: :status`, so every fixture here
# shares one status to stay in a single positioning group.
class Plutonium::Resource::Controllers::PositionActionsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html"
  COLLECTION_TARGET = 'target="pu-collection-tasks"'

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @a = Task.create!(title: "Alpha", status: "todo")
    @b = Task.create!(title: "Beta", status: "todo")
    @c = Task.create!(title: "Gamma", status: "todo")
  end

  teardown { Task.delete_all }

  def reposition(record, **params)
    post "/admin/tasks/#{record.id}/reposition",
      params: params,
      headers: {"Accept" => TURBO_STREAM_ACCEPT}
  end

  # ─── Happy path ────────────────────────────────────────────────────────────

  test "repositions a record between two neighbours" do
    # Drag Gamma (last) between Alpha and Beta.
    reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)

    @a.reload
    @b.reload
    @c.reload
    assert @a.position < @c.position, "Gamma must sit after Alpha"
    assert @c.position < @b.position, "Gamma must sit before Beta"
  end

  test "a clean drop answers 204 with an empty body" do
    reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)

    assert_response :no_content
    assert_predicate response.body, :empty?,
      "an optimistically-moved row needs no payload — 204 must carry no HTML"
  end

  test "a drop at the end of the list is clean (blank next_id is not drift)" do
    # A blank neighbour id means "there is no row on that side", which is a
    # legitimate end-of-list drop — NOT an id that failed to resolve.
    reposition(@a, prev_id: @c.id, next_id: "", to_index: 2)

    assert_response :no_content
    assert @a.reload.position > @c.reload.position, "Alpha must land after Gamma"
  end

  test "a drop at the top of the list is clean (blank prev_id is not drift)" do
    reposition(@c, prev_id: "", next_id: @a.id, to_index: 0)

    assert_response :no_content
    assert @c.reload.position < @a.reload.position
  end

  # ─── Rebalance forces reconciliation ───────────────────────────────────────

  test "a rebalance streams the collection back" do
    # Squeeze Alpha/Beta closer than EPSILON so inserting between them exhausts
    # the gap and reposition! renumbers the whole status group — every OTHER
    # row's position changes, so the client's optimistic view is stale.
    @a.update_column(:position, 1.0)
    @b.update_column(:position, 1.00000001)

    reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)

    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
    assert_includes response.body, COLLECTION_TARGET,
      "a rebalance must stream the collection into its wrapper"
    assert_includes response.body, "Alpha"
  end

  test "a rebalance still lands the record between its neighbours" do
    @a.update_column(:position, 1.0)
    @b.update_column(:position, 1.00000001)

    reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)

    assert_response :ok
    ordered = Task.where(status: "todo").order(:position).pluck(:title)
    assert_equal %w[Alpha Gamma Beta], ordered
  end

  # ─── Drift: a neighbour id that does not resolve ───────────────────────────

  test "an unresolvable neighbour id reconciles instead of answering 204" do
    # The client's view is stale (the neighbour it drew is gone / never was
    # visible to this user), so its optimistic move cannot be trusted.
    reposition(@c, prev_id: 999_999_999, next_id: @b.id, to_index: 1)

    assert_response :ok
    assert_includes response.body, COLLECTION_TARGET
  end

  test "an unresolvable neighbour is NOT silently coerced into an end-of-list drop" do
    # prev_id is bogus and next_id is Beta. Coercing the unresolved prev to nil
    # AND treating it as "no neighbour on that side" is what we must not do
    # silently: the record is placed before Beta and the client is told to
    # re-sync, rather than being left believing its own placement.
    reposition(@c, prev_id: 999_999_999, next_id: @b.id, to_index: 1)

    @b.reload
    @c.reload
    assert @c.position < @b.position, "the resolved neighbour still anchors the drop"
    refute_equal @c.position, Task.where(status: "todo").maximum(:position),
      "the record must not be appended to the end of the list"
  end

  # ─── Mode B: an opaque block write always reconciles ───────────────────────

  test "Mode B streams the collection on every drop" do
    moves = []
    with_position_config(Plutonium::Positioning::Config.with_block(:position, ->(move) { moves << move })) do
      reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)
    end

    assert_response :ok
    assert_includes response.body, COLLECTION_TARGET,
      "a block write is opaque — the framework cannot know what it renumbered"
    assert_equal 1, moves.size
    assert_equal @c.id, moves.first.record.id
    assert_equal @a.id, moves.first.prev.id
    assert_equal @b.id, moves.first.next.id
    assert_equal 1, moves.first.index
  end

  # ─── Not a reorderable resource ────────────────────────────────────────────

  test "a resource with no position_on answers 404" do
    post_record = create_post!
    comment = create_comment!(commentable: post_record)

    post "/admin/comments/#{comment.id}/reposition",
      params: {prev_id: "", next_id: "", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :not_found
  end

  test "Mode C (position_on false) answers 404" do
    with_position_config(Plutonium::Positioning::Config.disabled) do
      reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)
    end

    assert_response :not_found
  end

  # ─── Rejections ────────────────────────────────────────────────────────────

  test "a denied reposition? answers 403 with a stream, not an HTML error page" do
    original = @c.position

    TaskPolicy.deny_reposition = true
    begin
      reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)
    ensure
      TaskPolicy.deny_reposition = false
    end

    assert_response :forbidden
    assert_includes response.content_type, "turbo-stream",
      "the drag POST expects a stream — an HTML error page would be morphed into the table"
    assert_includes response.body, COLLECTION_TARGET
    assert_equal original, @c.reload.position, "a denied drop must not move anything"
  end

  test "a denied reposition? toasts the reason into the page flash region" do
    TaskPolicy.deny_reposition = true
    begin
      reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)
    ensure
      TaskPolicy.deny_reposition = false
    end

    assert_includes response.body, %(target="#{Plutonium::FLASH_REGION}"),
      "the snap-back must be explained, not silent"
    assert_includes response.body, "not authorized to reorder"
  end

  test "a record destroyed between render and drop answers 422 with a stream" do
    ghost_id = @c.id
    @c.destroy!

    post "/admin/tasks/#{ghost_id}/reposition",
      params: {prev_id: @a.id, next_id: @b.id, to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
    assert_includes response.body, COLLECTION_TARGET
    assert_includes response.body, "no longer exists"
  end

  test "a validation failure answers 422 carrying the record's own messages" do
    # The write that fails is the positioning write itself — here a Mode B block
    # whose update! rejects the record, which is exactly how an app-owned
    # positioning gem surfaces a rejected move.
    invalid = ->(move) { move.record.update!(title: "") }

    with_position_config(Plutonium::Positioning::Config.with_block(:position, invalid)) do
      reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)
    end

    assert_response :unprocessable_content
    assert_includes response.body, COLLECTION_TARGET
    assert_includes response.body, "Title can&#39;t be blank"
    assert_equal "Gamma", @c.reload.title, "the failed write must not persist"
  end

  # ─── The streamed collection belongs to the INDEX page, not to this POST ───

  test "the streamed collection's links point at the index, not the reposition path" do
    # Regression guard for the current_page_path / pagy_request_context seams:
    # the collection is re-rendered from a POST to a member path, but every URL
    # in it (sort headers, search form, row action return_to, pagination) must
    # address the collection page — a link to /admin/tasks/:id/reposition is a
    # GET on a POST-only route, i.e. a 404 waiting for a click.
    @a.update_column(:position, 1.0)
    @b.update_column(:position, 1.00000001)

    reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)

    assert_response :ok
    refute_includes response.body, "reposition",
      "no URL in the re-rendered collection may address the reposition endpoint"
  end

  test "the streamed collection honours the index query string sent with the drop" do
    @a.update_column(:position, 1.0)
    @b.update_column(:position, 1.00000001)

    # The client posts to the member path carrying the collection's own query —
    # here a search that hides everything but Alpha.
    post "/admin/tasks/#{@c.id}/reposition?q%5Bsearch%5D=Alpha",
      params: {prev_id: @a.id, next_id: @b.id, to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    assert_includes response.body, "Alpha"
    refute_includes response.body, "Gamma",
      "the re-rendered collection must be the filtered list the user is looking at"
  end

  private

  # Swaps TaskDefinition's position config for the duration of the block. The
  # definition's real `position_on` (Mode A) stays in force everywhere else —
  # this only exercises the other two modes without a second dummy resource.
  def with_position_config(config)
    original = TaskDefinition.defined_position_config
    TaskDefinition.defined_position_config = config
    yield
  ensure
    TaskDefinition.defined_position_config = original
  end
end

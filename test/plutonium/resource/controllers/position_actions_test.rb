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
#   * a blank neighbour id means "end of the PAGE", never "end of the group":
#     the real boundary neighbour is looked up, so a bottom-of-page or
#     bottom-of-filtered-list drop cannot write a duplicate position
#   * a neighbour from another positioning group is drift, not an anchor
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

  # ─── A blank neighbour is the end of the PAGE, not of the group ────────────

  test "a bottom-of-page drop interleaves with the hidden next row, never duplicating it" do
    # 30 rows, Pagy's default limit of 20. Dragging row 1 to the bottom of page
    # one sends prev_id = the last VISIBLE row and a blank next_id — and rows
    # 21..30 are still there, one of them at exactly last_visible + 1. Anchoring
    # off nil would compute that value and tie the two rows together, silently,
    # behind a 204.
    Task.delete_all
    30.times { |i| Task.create!(title: "Task #{i + 1}", status: "todo") }
    page1 = Task.where(status: "todo").order(:position).limit(20).to_a
    dragged = page1.first
    last_visible = page1.last
    hidden_next = Task.where(status: "todo").order(:position).offset(20).first

    reposition(dragged, prev_id: last_visible.id, next_id: "", to_index: 19)

    assert_response :no_content
    assert_no_duplicate_positions
    assert dragged.reload.position > last_visible.reload.position
    assert dragged.position < hidden_next.reload.position,
      "the drop must land between the last visible row and the first hidden one"
  end

  test "a bottom-of-filtered-list drop interleaves with the filtered-out next row" do
    # Filters hide rows just as pagination does: Hidden sits after Keep B in the
    # group but is filtered out of the view, so "no row below Keep B" is a claim
    # about the viewport only.
    Task.delete_all
    keep_a = Task.create!(title: "Keep A", status: "todo")
    keep_b = Task.create!(title: "Keep B", status: "todo")
    hidden = Task.create!(title: "Hidden", status: "todo")

    post "/admin/tasks/#{keep_a.id}/reposition?q%5Bsearch%5D=Keep",
      params: {prev_id: keep_b.id, next_id: "", to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :no_content
    assert_no_duplicate_positions
    assert keep_a.reload.position > keep_b.reload.position, "Keep A must follow Keep B"
    assert keep_a.position < hidden.reload.position,
      "the drop must land before the filtered-out row, not on top of it"
  end

  test "a top-of-page drop interleaves with the hidden previous row" do
    # The mirror case: blank prev_id on page 2 would compute next - 1, which is
    # the position of the last row of page 1.
    Task.delete_all
    30.times { |i| Task.create!(title: "Task #{i + 1}", status: "todo") }
    rows = Task.where(status: "todo").order(:position).to_a
    hidden_prev = rows[19]      # last row of page 1
    first_visible = rows[20]    # first row of page 2
    dragged = rows[29]          # last row of page 2

    post "/admin/tasks/#{dragged.id}/reposition?page=2",
      params: {prev_id: "", next_id: first_visible.id, to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :no_content
    assert_no_duplicate_positions
    assert dragged.reload.position < first_visible.reload.position
    assert dragged.position > hidden_prev.reload.position,
      "the drop must land after the last row of the previous page"
  end

  # ─── A neighbour from another positioning group is drift ───────────────────

  test "a neighbour in a different positioning group is drift, not an anchor" do
    # Task is `positioned_on :position, scope: :status`, so the index lists
    # several groups with independent, interleaved numberings. A "done" row at
    # 500.0 says nothing about where a "todo" row belongs.
    done = Task.create!(title: "Done", status: "done")
    done.update_column(:position, 500.0)
    original = @a.position

    reposition(@a, prev_id: done.id, next_id: "", to_index: 5)

    assert_response :ok, "an out-of-group neighbour is stale drift — reconcile, don't 204"
    assert_equal original, @a.reload.position,
      "with no usable anchor the record must not be flung to the end of its own group"
  end

  test "a same-group neighbour is still accepted after the group check" do
    reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)

    assert_response :no_content
    assert @a.reload.position < @c.reload.position
    assert @c.position < @b.reload.position
  end

  # ─── The list must be ordered by position for a drop to mean anything ──────

  test "a drop under a descending position sort is rejected without writing" do
    original = @c.position

    post "/admin/tasks/#{@c.id}/reposition?q%5Bsort_fields%5D%5B%5D=position&q%5Bsort_directions%5D%5Bposition%5D=DESC",
      params: {prev_id: @a.id, next_id: @b.id, to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
    assert_includes response.body, COLLECTION_TARGET
    assert_includes response.body, "sorted by position"
    assert_equal original, @c.reload.position,
      "under a reversed sort the neighbours mean the opposite of what a write would assume"
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

  test "Mode B receives the client's neighbours verbatim, blanks included" do
    # A block owns its own storage AND its own notion of neighbours, so neither
    # the boundary lookup nor the group check may rewrite what it is handed.
    moves = []
    with_position_config(Plutonium::Positioning::Config.with_block(:position, ->(move) { moves << move })) do
      reposition(@a, prev_id: @c.id, next_id: "", to_index: 2)
    end

    assert_response :ok
    assert_equal @c.id, moves.first.prev.id
    assert_nil moves.first.next, "a blank next_id must reach the block as nil"
  end

  test "Mode B index is floor-clamped, mirroring the kanban drop" do
    moves = []
    with_position_config(Plutonium::Positioning::Config.with_block(:position, ->(move) { moves << move })) do
      reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: -5)
    end

    assert_equal 0, moves.first.index,
      "a negative index would address a block author's array from the END"
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

  test "a drop while the kanban view is selected answers 404" do
    # The board has its own endpoint (kanban_move) and renders no collection
    # wrapper, so a reconciliation here would be a stream Turbo silently drops.
    original = @c.position

    post "/admin/tasks/#{@c.id}/reposition?view=kanban",
      params: {prev_id: @a.id, next_id: @b.id, to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :not_found
    assert_equal original, @c.reload.position
  end

  # ─── Rejections ────────────────────────────────────────────────────────────

  test "a denied index? answers 403 WITHOUT the collection" do
    # You must be able to see a list to reorder it. reposition? alone is not
    # enough: the reconciliation render would hand the whole listing to a user
    # the policy has refused it to.
    TaskPolicy.deny_index = true
    begin
      reposition(@c, prev_id: @a.id, next_id: @b.id, to_index: 1)
    ensure
      TaskPolicy.deny_index = false
    end

    assert_response :forbidden
    assert_predicate response.body, :empty?, "a refused listing must not be streamed back"
    refute_includes response.body, "Alpha"
  end

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

    # The ONE reposition path the collection is allowed to carry: the drag
    # controller's own template, which must be the COLLECTION's member path with
    # an __ID__ placeholder — never this request's /admin/tasks/:id/reposition.
    assert_includes response.body,
      "data-positioned-url-template-value=\"/admin/tasks/__ID__/reposition\""

    without_template = response.body.gsub(
      /data-positioned-url-template-value="[^"]*"/, ""
    )
    refute_includes without_template, "reposition",
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

  # ─── Nested association tables ─────────────────────────────────────────────
  #
  # Catalog::Variant is `positioned_on :position, scope: :product_id` and its
  # definition declares `position_on`, so a product's variants table — rendered
  # in a turbo-frame on the product's show page, at
  # /admin/catalog/products/:id/nested_variants — is drag-reorderable. That
  # nested route is the one place resource_url_for needs `parent:` to resolve
  # the collection the drop belongs to.

  test "a nested drop reorders within the parent's collection" do
    product, variants = create_positioned_variants
    first, second, third = variants

    post nested_variant_reposition_path(product, third),
      params: {prev_id: first.id, next_id: second.id, to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :no_content
    assert first.reload.position < third.reload.position
    assert third.position < second.reload.position
  end

  test "a nested reconciliation streams links for the NESTED collection" do
    product, variants = create_positioned_variants
    first, second, third = variants
    # Squeeze the gap so the drop rebalances and the collection comes back.
    first.update_column(:position, 1.0)
    second.update_column(:position, 1.00000001)

    post nested_variant_reposition_path(product, third),
      params: {prev_id: first.id, next_id: second.id, to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    nested_path = "/admin/catalog/products/#{product.id}/nested_variants"
    # Prefix match on purpose: pagy appends its own params to the per-page
    # option values (?page=1&limit=20), and which ones it appends is pagy's
    # business. What this test is the authority on is the PATH they hang off.
    assert_includes response.body, %(value="#{nested_path}?page=1),
      "pagination must address the nested collection, not the top-level one"
    assert_includes response.body, CGI.escape(nested_path),
      "a row action's return_to must come back to the nested table"
    refute_includes response.body, "/admin/catalog/variants",
      "a link to the top-level collection would navigate the user out of the frame"
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

  def assert_no_duplicate_positions(scope = Task.where(status: "todo"))
    duplicates = scope.pluck(:position).tally.select { |_, count| count > 1 }
    assert_empty duplicates,
      "a drop must never tie two rows to the same position (#{duplicates.transform_keys(&:to_f)})"
  end

  def create_positioned_variants
    product = create_product!
    variants = 3.times.map { |i| create_variant!(product: product, name: "Variant #{i + 1}") }
    [product, variants]
  end

  def nested_variant_reposition_path(product, variant)
    "/admin/catalog/products/#{product.id}/nested_variants/#{variant.id}/reposition"
  end
end

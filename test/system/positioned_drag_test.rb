# frozen_string_literal: true

require "application_system_test_case"

# Browser-level regression gate for drag-to-reorder on the two INDEX surfaces —
# the table (Task 7) and the card grid (Task 8).
#
# Everything below this file is already covered without a browser: the endpoint
# by test/plutonium/resource/controllers/position_actions_test.rb, the rendered
# DOM contract by test/plutonium/ui/{table,grid}/resource_test.rb. What none of
# those can reach is the half that only exists at runtime — the `positioned`
# Stimulus controller, its geometry maths, its fetch, and how it treats what the
# server sends back. That is what this file exists for.
#
# ## What is driven by a REAL pointer, and what is not
#
# Native HTML5 drag-and-drop is famously resistant to synthetic input, so the
# two halves of a drag are driven by two different mechanisms and this file is
# deliberate about which is which:
#
#   * DRAG INITIATION is genuinely native. `native_drag_start_from` presses and
#     moves a real mouse through the Chrome DevTools Protocol and lets the
#     BROWSER decide whether that gesture begins a drag. Nothing is simulated:
#     if `draggable="true"` were removed from the grip, no dragstart would fire
#     and "only the grip is draggable" would fail. That test is the one that
#     matters most for a real pointer, because the grip's whole reason to exist
#     is which element the browser treats as draggable.
#
#   * THE DROP is synthesised, by dispatching the real `dragover`/`drop`
#     DragEvents with a shared DataTransfer at real coordinates — the same
#     technique test/system/admin_portal/kanban_drop_interaction_test.rb already
#     uses. Selenium 4.43 removed async CDP event subscription, so Chrome's
#     `Input.dragIntercepted` payload (which a fully native drop must echo back)
#     cannot be captured from Ruby. What this costs is ONLY Chrome's internal
#     pointer→drop-event translation. Everything downstream is the genuine
#     article: the real controller's #onDrop, real getBoundingClientRect
#     geometry, the real drop-index maths, the real POST, the real server, and
#     the real handling of its 204 / turbo-stream answer.
#
#   * THE KEYBOARD PATH is entirely real — a real key press through the driver,
#     no synthesis at all. It runs the SAME #applyMove, the same endpoint and
#     the same response handling as a drop, so "an arrow key reorders and it
#     sticks" is a genuine end-to-end proof of the write path.
#
# ## Why every task is created with the same status
#
# Task declares `positioned_on :position, scope: :status`, so positions are only
# comparable WITHIN a status. Mixed statuses would put these rows in different
# positioning groups and make the expected order meaningless.
class PositionedDragTest < ApplicationSystemTestCase
  setup do
    @admin = create_admin!
    # Created in position order 1, 2, 3 — all in one positioning group.
    @alpha = Task.create!(title: "Alpha", status: "todo")
    @bravo = Task.create!(title: "Bravo", status: "todo")
    @charlie = Task.create!(title: "Charlie", status: "todo")
  end

  teardown { Task.delete_all }

  # ─── 1. A drag persists ─────────────────────────────────────────────────────

  test "dragging the first row to the end reorders it and the order survives a reload" do
    open_task_index

    assert_equal [@alpha.id, @bravo.id, @charlie.id], rendered_row_ids

    drag_first_to_end

    # The optimistic DOM moved...
    assert_row_ids [@bravo.id, @charlie.id, @alpha.id]
    # ...and the server agreed. Ordering by position is the only honest read:
    # the endpoint is free to choose any values that produce this sequence.
    assert_persisted_titles %w[Bravo Charlie Alpha]

    # The real proof: a fresh render from the database, not the optimistic DOM.
    open_task_index
    assert_equal [@bravo.id, @charlie.id, @alpha.id], rendered_row_ids
  end

  # ─── 2. Only the grip is draggable ──────────────────────────────────────────
  #
  # This is the whole reason the grip exists rather than making the <tr> itself
  # draggable, and both halves of it are silent regressions if they break:
  # `draggable="true"` disables text selection inside the element in every major
  # browser, and row_click_controller already makes the row the Show affordance,
  # so a draggable row turns a drag that ends in place into a navigation.
  test "the grip is draggable and the row is not — statically and to a real pointer" do
    open_task_index

    # (a) The static contract, asserted over every row on the page.
    row_draggables = page.evaluate_script(
      "[...document.querySelectorAll('tbody tr')].map(r => String(r.getAttribute('draggable')))"
    )
    assert row_draggables.any?, "expected the table to have rendered some rows"
    assert_equal ["null"] * row_draggables.size, row_draggables,
      "no <tr> may carry draggable=true — it would kill text selection and fight row-click"

    grip_draggables = page.evaluate_script(
      "[...document.querySelectorAll('[data-positioned-grip]')].map(g => g.getAttribute('draggable'))"
    )
    assert_equal 3, grip_draggables.size, "every row must render a grip"
    assert_equal ["true"] * 3, grip_draggables, "the grip is the draggable element"

    # (b) The contract as CHROME reads it. A real mouse press-and-move on the
    # grip must begin a drag; the identical gesture on the row body must not.
    # Nothing here is dispatched by hand — the browser is the one deciding.
    record_dragstarts

    native_drag_start_from(*grip_center)
    assert_equal ["grip"], observed_dragstarts,
      "a real pointer drag from the grip must start a drag"

    reset_pointer
    record_dragstarts

    native_drag_start_from(*row_body_center)
    assert_empty observed_dragstarts,
      "a real pointer drag from the row body must NOT start a drag"
  ensure
    reset_pointer
  end

  # ─── 3. Row-click still works ───────────────────────────────────────────────

  test "clicking a row body still opens the record's show page" do
    open_task_index

    # A real click on the row's own content, exactly as a user would.
    find("td", text: "Alpha", match: :first).click

    assert_current_path(/\/admin\/tasks\/#{@alpha.id}(\?|$)/, wait: 5, ignore_query: false)
    assert_text "Alpha"
  end

  # ─── 4. Keyboard reorder ────────────────────────────────────────────────────
  #
  # Native HTML5 DnD is mouse-only, so without this the grip would be a tab stop
  # that does nothing. The key press here is real; only the focus is scripted
  # (the grip is opacity-0 until hovered or focused, so it cannot be tabbed to
  # deterministically from an arbitrary starting point — but `focus:opacity-100`
  # means that once focused it IS visible, which the assertion below pins).
  test "ArrowDown on a focused grip moves the row down and persists it" do
    open_task_index

    focus_first_grip
    assert page.has_selector?("[data-positioned-grip]:focus"),
      "a focused grip must become visible, or the keyboard affordance is invisible in use"

    press_arrow(:arrow_down)

    assert_row_ids [@bravo.id, @alpha.id, @charlie.id]
    assert_persisted_titles %w[Bravo Alpha Charlie]

    # Focus follows the record it was on — moving a node in the DOM otherwise
    # drops focus and strands the user after a single keypress.
    focused_id = page.evaluate_script(
      "document.activeElement.closest('[data-positioned-row-id]')?.dataset.positionedRowId"
    )
    assert_equal @alpha.id.to_s, focused_id, "focus must travel with the moved row"

    open_task_index
    assert_equal [@bravo.id, @alpha.id, @charlie.id], rendered_row_ids
  end

  # ─── 5. The disabled state, and the way out of it ───────────────────────────
  #
  # A drop only describes a position when the visual order IS the stored order,
  # so the server rejects one made under any other sort — including a DESCENDING
  # position sort. Rather than hiding the affordance (leaving no hint the table
  # is reorderable and no way to make it so), it renders as a link that applies
  # the ascending sort. The disabled state is itself the way out of it.
  test "a descending position sort disables dragging, and the grip links back to ascending" do
    open_task_index
    visit position_sort_url(:desc)
    assert_selector "table", wait: 5

    # Sanity: we really are looking at the descending order. Read off the show
    # links rather than the row ids, because `data-positioned-row-id` is emitted
    # only while dragging is live — under this sort the rows carry no drag
    # identity at all, which is itself part of the contract.
    assert_equal [@charlie.id, @bravo.id, @alpha.id], rendered_show_link_ids
    assert_equal 0, page.evaluate_script("document.querySelectorAll('[data-positioned-row-id]').length"),
      "a row must not advertise a drag identity when no drop could be honoured"

    refute page.evaluate_script("!!document.querySelector('[data-controller~=\"positioned\"]')"),
      "the drag controller must not be wired under a sort the server would reject"
    assert_equal 0, page.evaluate_script("document.querySelectorAll('[data-positioned-grip]').length"),
      "no live grip may be offered when a drop cannot be honoured"

    # The disabled affordance is present and is a link back to ascending.
    assert_selector "a[title='Sort by position to reorder']", visible: :all, count: 3

    click_disabled_grip

    # Following it restores the live, draggable grips.
    assert_selector "[data-controller~='positioned']", wait: 5
    assert_equal 3, page.evaluate_script("document.querySelectorAll('[data-positioned-grip]').length"),
      "the disabled grip must lead back to a state where dragging is live"
    assert_equal [@alpha.id, @bravo.id, @charlie.id], rendered_row_ids
  end

  # ─── 6. The grid surface ────────────────────────────────────────────────────
  #
  # The grid is a second CONSUMER of the same controller, differing only in which
  # axis a drop index is read off (cards wrap; rows stack). Proving a drop lands
  # and persists there proves the horizontal path is wired, not just present.
  test "dragging the first card to the end of the grid reorders it and persists" do
    open_task_index(view: "grid")

    assert page.has_selector?("[data-positioned-axis-value='horizontal']"),
      "the grid must declare the horizontal drop axis — cards wrap, they do not stack"
    assert_equal [@alpha.id, @bravo.id, @charlie.id], rendered_row_ids

    drag_first_to_end(axis: :horizontal)

    assert_row_ids [@bravo.id, @charlie.id, @alpha.id]
    assert_persisted_titles %w[Bravo Charlie Alpha]

    open_task_index(view: "grid")
    assert_equal [@bravo.id, @charlie.id, @alpha.id], rendered_row_ids
  end

  # ─── 7. A clean drop does not repaint ───────────────────────────────────────
  #
  # A drop that needed no rebalance answers 204, precisely so the collection is
  # NOT re-rendered: the optimistic DOM is already right, and repainting would
  # cost a flash and the user's focus. "Was it repainted?" is invisible to any
  # assertion about content — identical HTML is the expected result either way —
  # so the test stamps a witness attribute on every row FIRST. A witness can only
  # survive if those exact DOM nodes were never replaced.
  test "a clean drop leaves the existing rows in place rather than re-rendering them" do
    open_task_index

    stamp_row_witnesses

    drag_first_to_end

    assert_row_ids [@bravo.id, @charlie.id, @alpha.id]
    assert_persisted_titles %w[Bravo Charlie Alpha]

    assert_equal ["w#{@bravo.id}", "w#{@charlie.id}", "w#{@alpha.id}"], surviving_row_witnesses,
      "the 204 path must move the existing rows, not replace the collection"
  end

  # ─── 7. Focus survives a reconciliation ─────────────────────────────────────
  #
  # The 204 path leaves the DOM alone, so focus never moves. The STREAM path
  # replaces the collection wrapper's contents — and the controller's own element
  # (the div around the <table>) is one of the nodes discarded with it. Restoring
  # focus therefore cannot be done through `this.element`: by the time the
  # callback runs, that belongs to a detached tree.
  #
  # Provoked with a real rebalance rather than a stub: Bravo and Charlie are
  # 1e-7 apart, inside EPSILON, so there is no midpoint to give Alpha and the
  # whole group is renumbered — which is exactly when the server streams.
  test "a keyboard move that forces a rebalance keeps focus on the moved row" do
    @bravo.update_column(:position, 2.0)
    @charlie.update_column(:position, 2.0000001)

    open_task_index
    assert_equal [@alpha.id, @bravo.id, @charlie.id], rendered_row_ids

    stamp_row_witnesses
    focus_first_grip
    press_arrow(:arrow_down)

    assert_row_ids [@bravo.id, @alpha.id, @charlie.id]
    assert_persisted_titles %w[Bravo Alpha Charlie]

    # Two independent witnesses that this went down the STREAM path, not the 204
    # one — which is the whole premise of the focus assertion below.
    #
    # A row the user never touched was renumbered: Charlie sat at 2.0000001 and
    # only a rebalance moves it.
    assert_equal 3.0, Task.uncached { Task.find(@charlie.id).position }.to_f,
      "the exhausted gap should have renumbered the whole group"
    # And the collection itself was replaced: no stamped node survived. Polled,
    # because the write landing in the database is not the stream having
    # rendered — assert_persisted_titles above returns as soon as the POST
    # commits, which can be a frame or two before Turbo swaps the rows in.
    assert_no_surviving_row_witnesses

    assert_focused_row @alpha.id,
      "focus must land on the moved row's grip in the REPLACED collection"
  end

  # ─── 8. A move the server never confirms is undone ──────────────────────────
  #
  # The row is moved optimistically before the POST, so any outcome that is not
  # the server's own truth has to put it back. Leaving it is what the kanban
  # board does, correctly — native DnD never re-parents a card there — but a
  # reorder DOES re-parent, so the same choice here leaves the user looking at an
  # order that was never written, with nothing to hint at it but a reload.
  #
  # Driven by failing the request rather than the server: offline, a dropped
  # connection and an aborted navigation are the realistic causes, and none of
  # them can be produced from the Rails side.
  test "a failed reposition request puts the row back" do
    open_task_index
    stub_reposition_failure

    focus_first_grip
    press_arrow(:arrow_down)

    # Non-vacuous: the controller only POSTs after moving the row, and it skips
    # the POST entirely when a move would be a no-op. One attempt therefore
    # proves the optimistic move happened and the assertion below is a revert
    # rather than a move that never occurred.
    assert_reposition_attempted

    assert_row_ids [@alpha.id, @bravo.id, @charlie.id]
    assert_persisted_titles %w[Alpha Bravo Charlie]

    assert_focused_row @alpha.id,
      "the keyboard path leaves the user on this grip; a revert must not strand them"
  end

  # ─── 9. The drag ghost is the row, not the grip ─────────────────────────────
  #
  # The browser ghosts whatever carries draggable="true" — here the grip — so
  # without an explicit setDragImage the user drags a picture of a 20px handle
  # and the row appears not to move at all. Asserted by spying on the real
  # DataTransfer method, because the ghost is a compositor artefact: it exists
  # in no DOM this test could read.
  test "the drag ghost is the whole row, not the grip that started it" do
    open_task_index
    spy_set_drag_image

    dispatch_dragstart_on_first_grip

    ghost = page.evaluate_script("window.__puGhost")
    refute_nil ghost, "the controller must name a drag image; the default ghost is the grip alone"
    assert_equal "TR", ghost["tag"],
      "the ghost must be the row being moved, not the grip or an ancestor"
    assert_equal @alpha.id.to_s, ghost["rowId"], "and specifically the row that was grabbed"
  end

  # ─── 10. The insertion marker ───────────────────────────────────────────────
  #
  # Without it the only feedback mid-drag is the ghost under the cursor, which
  # says WHAT is moving but never WHERE it will land — the user aims blind until
  # release. The marker must also agree with the drop: it is drawn from the same
  # index the drop uses, so a line that disagrees with the resulting order is a
  # regression this asserts against directly.
  test "a marker shows where the drop will land, and clears when the drag ends" do
    open_task_index

    # Index 2 of the rows OTHER than the dragged one — i.e. the gap between
    # Bravo and Charlie. Index 1 would be the leading edge, which has no row
    # above it and so no gap to centre in.
    marker = marker_state_over_row(2)

    assert marker["present"], "a drag with no insertion marker gives the user nothing to aim at"
    assert_equal "block", marker["display"]
    assert_equal "between", marker["edge"],
      "a drop between two rows must centre in their gap, not hug one row's edge"
    # SYMMETRY is the claim, not clearance: the line centres on the gap the
    # layout leaves, so it gets equal air above and below whatever that gap is.
    # Table rows are adjacent, so the gap is zero and a 2px line straddles the
    # boundary 1px into each row — which is the correct rendering, and the same
    # rule that gives a board's roomier columns real space on both sides.
    assert_in_delta marker["spaceAbove"], marker["spaceBelow"], 1,
      "the marker must sit centred between the two rows, not biased toward one"

    end_drag
    refute page.evaluate_script(
      "(() => { const m = document.getElementById('pu-drag-insertion-marker'); return !!m && m.style.display === 'block' })()"
    ), "the marker must not outlive the gesture that drew it"
  end

  # ─── 11. A drop across positioning groups is refused by the drag itself ─────
  #
  # Task is scoped by status, so each status keeps an independent sequence and a
  # drop between two rows of different statuses describes no position at all.
  # The server refuses it either way; the point of the client half is that the
  # user finds out BEFORE committing, instead of watching the row snap back.
  test "dragging across positioning groups is refused, with no marker and no write" do
    # A second group on the same page. Its position is irrelevant — what matters
    # is that it is a different status from the rows created in setup.
    other = Task.create!(title: "Zulu", status: "doing")
    open_task_index

    groups = page.evaluate_script(
      "[...document.querySelectorAll('[data-positioned-row-id]')].map(r => r.dataset.positionedGroup)"
    )
    assert_includes groups, "todo", "the row's positioning group must reach the DOM"
    assert_includes groups, "doing", "both groups must be on the page for this to test anything"

    before = rendered_row_ids
    refused = dragover_across_groups(from_id: @alpha.id, to_id: other.id)

    refute refused["dropAllowed"],
      "withholding preventDefault is what makes the browser show 'no entry' and suppress the drop"
    refute refused["markerVisible"],
      "a marker would promise a drop that cannot happen"

    end_drag
    assert_equal before, rendered_row_ids, "nothing may move on a refused drag"
    assert_equal "doing", other.reload.status
    assert_persisted_titles %w[Alpha Bravo Charlie]
  end

  private

  # ─── navigation ─────────────────────────────────────────────────────────────

  # Land on the Task index, logging in on the first call. `position_on` makes
  # ascending position the default sort, so dragging is live without any params.
  def open_task_index(view: nil)
    visit(view ? "/admin/tasks?view=#{view}" : "/admin/tasks")

    if page.has_field?("login", wait: 2)
      fill_in "login", with: @admin.email
      click_button "Login"
      fill_in "password", with: "password123"
      click_button "Login"
    end

    assert_selector "[data-positioned-row-id]", minimum: 1, wait: 5
  end

  # The index under an explicit position sort. Built by hand rather than read off
  # the page so the disabled-state test can reach the descending order without
  # first depending on the very link it is there to verify.
  def position_sort_url(direction)
    "/admin/tasks?q%5Bsort_fields%5D%5B%5D=position" \
      "&q%5Bsort_directions%5D%5Bposition%5D=#{direction}"
  end

  # The disabled grip is opacity-0 until its row is hovered, so it is not a
  # Capybara-visible click target; the navigation it triggers is the point.
  def click_disabled_grip
    page.execute_script("document.querySelector(\"a[title='Sort by position to reorder']\").click()")
  end

  # ─── observation ────────────────────────────────────────────────────────────

  def rendered_row_ids
    page.evaluate_script(
      "[...document.querySelectorAll('[data-positioned-row-id]')].map(r => r.dataset.positionedRowId)"
    ).map(&:to_i)
  end

  # Row order derived from each row's Show link instead of its drag identity —
  # the only reading that works when dragging is DISABLED, since a row carries
  # no `data-positioned-row-id` then.
  def rendered_show_link_ids
    page.evaluate_script(<<~JS).map(&:to_i)
      [...document.querySelectorAll("tbody tr [data-row-click-target='show']")]
        .map(link => link.getAttribute("href").match(/\\/tasks\\/(\\d+)/)[1])
    JS
  end

  # Waits for the optimistic move AND the POST it triggers to settle. Capybara's
  # retrying matchers do not cover evaluate_script, so poll it explicitly.
  def assert_row_ids(expected)
    deadline = Time.now + Capybara.default_max_wait_time
    actual = nil
    while Time.now < deadline
      actual = rendered_row_ids
      break if actual == expected
      sleep 0.1
    end
    assert_equal expected, actual, "the rows did not settle into the expected order"
  end

  # The order actually stored, by position. Polled because the optimistic DOM
  # move happens BEFORE the POST resolves — reading the table the instant the
  # rows shift would race the write it is meant to be checking.
  #
  # Ordering by position rather than asserting specific values on purpose: the
  # endpoint is free to pick any numbers that produce this sequence (and will
  # pick different ones after a rebalance).
  #
  # `uncached` is LOAD-BEARING, not caution. The write happens on the Puma
  # thread's connection; this polls on the test process's own. With the query
  # cache live, the first read of the loop is the only one that touches the
  # database — every later iteration is served the same stale rows, so a poll
  # that starts a few milliseconds before the POST lands can never observe it
  # and the loop spins out its full deadline against a memoized answer. That
  # produced exactly one spurious failure per run, moving between tests with the
  # seed, while each test passed alone.
  def assert_persisted_titles(expected)
    deadline = Time.now + Capybara.default_max_wait_time
    titles = nil
    while Time.now < deadline
      titles = Task.uncached { Task.where(status: "todo").order(:position).pluck(:title) }
      break if titles == expected
      sleep 0.1
    end
    assert_equal expected, titles, "the reposition POST did not persist the new order"
  end

  # ─── the drop half (synthesised — see the file header) ──────────────────────

  # Drags the first row/card to the last slot by dispatching the real DragEvents
  # the controller listens for, with one shared DataTransfer, at real
  # coordinates read off the live layout.
  #
  # The target point differs by surface for the same reason the controller's
  # #dropIndex does: a table is read on Y (just past the last row's midpoint), a
  # wrapped grid on X within the cursor's visual row (just past the last card's
  # horizontal midpoint).
  def drag_first_to_end(axis: :vertical)
    dispatched = page.evaluate_script(<<~JS)
      (() => {
        const rows = [...document.querySelectorAll("[data-positioned-row-id]")];
        if (rows.length < 2) return false;

        const source = rows[0];
        const grip = source.querySelector("[data-positioned-grip]");
        const last = rows[rows.length - 1];
        if (!grip) return false;

        const dt = new DataTransfer();
        // Dispatched on the GRIP: the browser would too, since the grip is the
        // draggable node. It bubbles to the controller's wrapper from there.
        grip.dispatchEvent(new DragEvent("dragstart",
          { bubbles: true, cancelable: true, dataTransfer: dt }));

        const rect = last.getBoundingClientRect();
        const point = #{(axis == :horizontal) ? "{ x: rect.right - 2, y: rect.top + rect.height / 2 }" : "{ x: rect.left + 40, y: rect.bottom - 2 }"};

        for (const type of ["dragover", "drop"]) {
          last.dispatchEvent(new DragEvent(type, {
            bubbles: true, cancelable: true, dataTransfer: dt,
            clientX: point.x, clientY: point.y
          }));
        }

        source.dispatchEvent(new DragEvent("dragend",
          { bubbles: true, cancelable: true, dataTransfer: dt }));
        return true;
      })()
    JS

    assert dispatched, "could not find a draggable row and a drop target to drag between"
  end

  # Replaces DataTransfer's own setDragImage with a recorder, before any drag
  # starts. The ghost is drawn by the compositor and appears in no DOM, so what
  # the controller ASKED for is the only observable fact about it.
  def spy_set_drag_image
    page.execute_script(<<~JS)
      window.__puGhost = null;
      const original = DataTransfer.prototype.setDragImage;
      DataTransfer.prototype.setDragImage = function (el, x, y) {
        window.__puGhost = { tag: el.tagName, rowId: el.dataset ? el.dataset.positionedRowId : null, x, y };
        return original.call(this, el, x, y);
      };
    JS
  end

  # Opens a drag on the first row's grip and leaves it open, so a caller can
  # observe mid-gesture state. Dispatched on the grip because that is where the
  # browser would raise it — the grip is the draggable node.
  def dispatch_dragstart_on_first_grip
    page.execute_script(<<~JS)
      window.__puDrag = new DataTransfer();
      const grip = document.querySelector("[data-positioned-grip]");
      grip.dispatchEvent(new DragEvent("dragstart", { bubbles: true, cancelable: true, dataTransfer: window.__puDrag }));
    JS
  end

  # Starts a drag on the first row, hovers the TOP edge of row `index`, and
  # reports what the marker did. The measurements are taken against the rows
  # either side so the assertions describe the gap, not absolute pixels.
  def marker_state_over_row(index)
    dispatch_dragstart_on_first_grip
    page.evaluate_script(<<~JS)
      (() => {
        const rows = [...document.querySelectorAll("[data-positioned-row-id]")];
        const dragged = rows[0];
        const others = rows.filter(r => r !== dragged);
        const target = others[#{index} - 1];
        const rect = target.getBoundingClientRect();
        document.querySelector('[data-controller~="positioned"]').dispatchEvent(new DragEvent("dragover", {
          bubbles: true, cancelable: true, dataTransfer: window.__puDrag,
          clientX: rect.left + 40, clientY: rect.top + 2
        }));

        const m = document.getElementById("pu-drag-insertion-marker");
        if (!m) return { present: false };
        const mr = m.getBoundingClientRect();
        const prev = others[#{index} - 2];
        return {
          present: true,
          display: m.style.display,
          edge: m.dataset.edge,
          spaceAbove: prev ? Math.round(mr.top - prev.getBoundingClientRect().bottom) : 0,
          spaceBelow: Math.round(rect.top - mr.bottom)
        };
      })()
    JS
  end

  # Drags `from_id` over `to_id` and reports whether the controller allowed it.
  # `dropAllowed` is the event's own defaultPrevented — the exact signal the
  # browser reads to decide between a move cursor and "no entry".
  def dragover_across_groups(from_id:, to_id:)
    page.evaluate_script(<<~JS)
      (() => {
        const byId = id => document.querySelector(`[data-positioned-row-id="${id}"]`);
        const source = byId(#{from_id});
        const target = byId(#{to_id});
        window.__puDrag = new DataTransfer();
        source.querySelector("[data-positioned-grip]")
          .dispatchEvent(new DragEvent("dragstart", { bubbles: true, cancelable: true, dataTransfer: window.__puDrag }));

        const rect = target.getBoundingClientRect();
        const ev = new DragEvent("dragover", {
          bubbles: true, cancelable: true, dataTransfer: window.__puDrag,
          clientX: rect.left + 40, clientY: rect.top + 4
        });
        target.dispatchEvent(ev);
        // A refused drop must ALSO be inert if the browser somehow delivered it.
        target.dispatchEvent(new DragEvent("drop", {
          bubbles: true, cancelable: true, dataTransfer: window.__puDrag,
          clientX: rect.left + 40, clientY: rect.top + 4
        }));

        const m = document.getElementById("pu-drag-insertion-marker");
        return { dropAllowed: ev.defaultPrevented, markerVisible: !!m && m.style.display === "block" };
      })()
    JS
  end

  # Closes whatever drag is open, so a test's teardown state is a page with no
  # gesture in flight.
  def end_drag
    page.execute_script(<<~JS)
      const row = document.querySelector("[data-positioned-row-id]");
      if (row) row.dispatchEvent(new DragEvent("dragend", { bubbles: true, cancelable: true, dataTransfer: window.__puDrag || new DataTransfer() }));
    JS
  end

  # ─── the native pointer half ────────────────────────────────────────────────

  # Records which element each dragstart originated from, so the native-gesture
  # test can tell "the browser started a drag on the grip" from "on something
  # else" — and from "not at all". Capture phase, so nothing can stop it first.
  def record_dragstarts
    page.execute_script(<<~JS)
      window.__dragStarts = [];
      if (!window.__dragStartRecorder) {
        window.__dragStartRecorder = event => {
          window.__dragStarts.push(
            event.target.closest("[data-positioned-grip]") ? "grip" : "other:" + event.target.tagName
          );
        };
        document.addEventListener("dragstart", window.__dragStartRecorder, true);
      }
    JS
  end

  def observed_dragstarts
    page.evaluate_script("window.__dragStarts")
  end

  # Presses a REAL mouse button at (x, y) and moves it, then lets Chrome decide
  # whether that gesture starts a drag. `Input.setInterceptDrags` keeps the drag
  # from escaping into the OS's drag loop (which would hang the session) while
  # still letting the page's own dragstart fire first.
  def native_drag_start_from(x, y)
    cdp("Input.setInterceptDrags", "enabled" => true)
    cdp("Input.dispatchMouseEvent",
      "type" => "mousePressed", "x" => x, "y" => y,
      "button" => "left", "buttons" => 1, "clickCount" => 1)
    # Two moves: the first crosses the browser's drag threshold, the second
    # travels far enough that a drag is unambiguously underway.
    cdp("Input.dispatchMouseEvent",
      "type" => "mouseMoved", "x" => x + 10, "y" => y + 10, "button" => "left", "buttons" => 1)
    cdp("Input.dispatchMouseEvent",
      "type" => "mouseMoved", "x" => x, "y" => y + 120, "button" => "left", "buttons" => 1)

    # Chrome dispatches dragstart asynchronously from the move; give it a beat.
    sleep 0.5
  end

  # Releases the button and stops intercepting, so a half-finished native drag
  # cannot leak into the next gesture or the next test.
  def reset_pointer
    cdp("Input.dispatchMouseEvent",
      "type" => "mouseReleased", "x" => 0, "y" => 0,
      "button" => "left", "buttons" => 0, "clickCount" => 1)
    cdp("Input.setInterceptDrags", "enabled" => false)
  end

  def cdp(command, params = {})
    page.driver.browser.execute_cdp(command, **params)
  end

  def grip_center
    point_from(<<~JS)
      document.querySelector("[data-positioned-grip]").getBoundingClientRect()
    JS
  end

  # The middle of the first row, which is row CONTENT — deliberately nowhere
  # near the grip tucked into the first cell's left padding.
  def row_body_center
    point_from(<<~JS)
      document.querySelector("[data-positioned-row-id]").getBoundingClientRect()
    JS
  end

  def point_from(rect_js)
    point = page.evaluate_script("(() => { const r = #{rect_js.strip}; return {x: r.left + r.width / 2, y: r.top + r.height / 2}; })()")
    [point["x"], point["y"]]
  end

  # ─── the keyboard half (entirely real) ──────────────────────────────────────

  # Focus is scripted, the key press is not. Focusing is what Tab would do, and
  # tabbing to it deterministically would mean asserting the whole page's tab
  # order — which is not what this test is about.
  def focus_first_grip
    page.execute_script("document.querySelector('[data-positioned-grip]').focus()")
    assert page.evaluate_script("document.activeElement.hasAttribute('data-positioned-grip')"),
      "the grip must be focusable — it is a real <button> precisely so it can be"
  end

  # Sent to the browser's active element, so this is a genuine key press against
  # whatever actually has focus, not a synthetic event aimed at a node.
  def press_arrow(key)
    page.driver.browser.action.send_keys(key).perform
  end

  # Which record the focused grip belongs to. Polled: on the stream path focus is
  # restored a frame after Turbo finishes rendering the replacement rows.
  def assert_focused_row(expected_id, message)
    deadline = Time.now + Capybara.default_max_wait_time
    focused = nil
    while Time.now < deadline
      focused = page.evaluate_script(<<~JS)
        document.activeElement?.closest?.("[data-positioned-grip]")
          ? document.activeElement.closest("[data-positioned-row-id]")?.dataset.positionedRowId
          : null
      JS
      break if focused.to_s == expected_id.to_s
      sleep 0.1
    end
    assert_equal expected_id.to_s, focused.to_s, message
  end

  # "Were these exact DOM nodes replaced?" is invisible to any assertion about
  # content — identical HTML is the expected result whether the collection was
  # re-rendered or its rows merely moved. So stamp every row first: a witness can
  # only survive if its node did. Used in both directions — the 204 path must
  # keep them, a reconciliation must not.
  def stamp_row_witnesses
    page.execute_script(<<~JS)
      document.querySelectorAll("[data-positioned-row-id]").forEach(row => {
        row.dataset.dropWitness = "w" + row.dataset.positionedRowId
      })
    JS
  end

  def surviving_row_witnesses
    page.evaluate_script(<<~JS).compact
      [...document.querySelectorAll("[data-positioned-row-id]")]
        .map(row => row.dataset.dropWitness ?? null)
    JS
  end

  def assert_no_surviving_row_witnesses
    deadline = Time.now + Capybara.default_max_wait_time
    surviving = nil
    while Time.now < deadline
      surviving = surviving_row_witnesses
      break if surviving.empty?
      sleep 0.1
    end
    assert_empty surviving,
      "a reconciliation must replace the collection, not move the existing rows"
  end

  # ─── failure injection ──────────────────────────────────────────────────────

  # Makes every reposition POST fail at the transport, the way being offline
  # does. Deliberately not a Rails-side rejection: the server answering at all
  # means a turbo-stream, which is the path that reconciles rather than reverts.
  # Other requests are left alone so the page keeps working.
  def stub_reposition_failure
    page.execute_script(<<~JS)
      window.__repositionAttempts = 0;
      const realFetch = window.fetch.bind(window);
      window.fetch = (input, init) => {
        if (String(input?.url ?? input).includes("/reposition")) {
          window.__repositionAttempts++;
          return Promise.reject(new TypeError("simulated network failure"));
        }
        return realFetch(input, init);
      };
    JS
  end

  def assert_reposition_attempted
    deadline = Time.now + Capybara.default_max_wait_time
    attempts = 0
    while Time.now < deadline
      attempts = page.evaluate_script("window.__repositionAttempts").to_i
      break if attempts.positive?
      sleep 0.1
    end
    assert_equal 1, attempts, "the controller should have moved the row and posted exactly once"
  end
end

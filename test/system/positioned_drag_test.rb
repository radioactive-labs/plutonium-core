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

    page.execute_script(<<~JS)
      document.querySelectorAll("[data-positioned-row-id]").forEach(row => {
        row.dataset.dropWitness = "w" + row.dataset.positionedRowId
      })
    JS

    drag_first_to_end

    assert_row_ids [@bravo.id, @charlie.id, @alpha.id]
    assert_persisted_titles %w[Bravo Charlie Alpha]

    witnesses = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-positioned-row-id]")]
        .map(row => String(row.dataset.dropWitness))
    JS
    assert_equal ["w#{@bravo.id}", "w#{@charlie.id}", "w#{@alpha.id}"], witnesses,
      "the 204 path must move the existing rows, not replace the collection"
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
end

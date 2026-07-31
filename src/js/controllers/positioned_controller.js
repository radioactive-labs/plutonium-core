import { Controller } from "@hotwired/stimulus"
import { beginDrag, computeDropIndex, endDrag } from "../drag/sortable"

// Applied to the row for the duration of the drag. A plain Tailwind utility
// rather than a bespoke class, so the whole affordance needs no stylesheet of
// its own — the same reason the grip itself is themed from Table::Theme.
const DRAGGING_CLASS = "opacity-30"

// Connects to data-controller="positioned"
//
// Drag-to-reorder for an index table whose resource declares `position_on`.
// Native HTML5 drag-and-drop, sharing its mechanics with the kanban board via
// ../drag/sortable — no npm dependency.
//
// ## DOM contract
//
// Table wrapper (this element — the div around <table>):
//   data-controller="positioned"
//   data-positioned-url-template-value="/things/__ID__/reposition"
//     — the collection path with an __ID__ placeholder, substituted with the
//       dragged row's record id at drop time.
//
// Row (<tr>):
//   data-positioned-row-id="<id>"
//     — the SINGLE source of truth for which record a drag is about. The grip
//       deliberately carries no id of its own: two places to read it from is
//       two places for them to disagree.
//
// Grip (a <button> inside the row's first cell):
//   data-positioned-grip
//
// ## Only the grip is draggable — never the <tr>
//
// Two concrete reasons, both of which cost real functionality if ignored:
//
//   1. `draggable="true"` disables text selection inside the element in every
//      major browser. On a data table that silently removes the ability to
//      select and copy a cell value.
//   2. row_click_controller makes the whole row the Show affordance. A
//      draggable row fights it: a drag that starts and ends in place still
//      fires a click, and the user is navigated away instead of being left
//      where they were.
//
// The kanban board keeps whole-card dragging because neither concern applies
// to a card. The inconsistency is deliberate.
//
// ## The wrapper only appears while the table IS in position order
//
// Under any other sort the visible neighbours sit in arbitrary position order,
// so "drop me between these two rows" describes nothing the server can honour
// — and it rejects such a drop outright (422, no write). The server-rendered
// table therefore omits this controller entirely under a foreign sort and
// renders the grip as a disabled link that applies the position sort instead.
// So this controller never has to reason about sorting: if it is connected,
// dragging is permitted.
//
// ## Move flow
//
// 1. dragstart — remember the row, apply the drag ghost + dimming.
// 2. dragover  — preventDefault so the browser offers a "move" cursor.
// 3. drop      — compute the insertion index against the OTHER rows, move the
//                row optimistically, then POST {prev_id, next_id, to_index}.
// 4. dragend   — clear the dimming and the cached row.
//
// Keyboard: the grip is a real <button>, so it is tabbable, and ArrowUp /
// ArrowDown move the focused row one slot through exactly the same path.
// Native HTML5 DnD is mouse-only — without this the feature is unusable by
// keyboard, and the affordance would be a tab stop that does nothing.
export default class extends Controller {
  static values = { urlTemplate: String }

  connect() {
    this.draggedRow = null

    this.onDragStart = this.#onDragStart.bind(this)
    this.onDragOver = this.#onDragOver.bind(this)
    this.onDrop = this.#onDrop.bind(this)
    this.onDragEnd = this.#onDragEnd.bind(this)
    this.onKeyDown = this.#onKeyDown.bind(this)

    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragover", this.onDragOver)
    this.element.addEventListener("drop", this.onDrop)
    this.element.addEventListener("dragend", this.onDragEnd)
    this.element.addEventListener("keydown", this.onKeyDown)
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragover", this.onDragOver)
    this.element.removeEventListener("drop", this.onDrop)
    this.element.removeEventListener("dragend", this.onDragEnd)
    this.element.removeEventListener("keydown", this.onKeyDown)
  }

  // ─── drag lifecycle ─────────────────────────────────────────────────────────

  #onDragStart(event) {
    // The grip is the only draggable node, but the event still bubbles from
    // whatever inside it the pointer grabbed (the icon's <svg>/<path>).
    const grip = event.target.closest("[data-positioned-grip]")
    if (!grip) return

    const row = this.#rowFor(grip)
    if (!row) return

    this.draggedRow = row
    // Dim the ROW, not the grip: the row is what the user is moving. The class
    // is applied one frame late by beginDrag so the drag ghost is snapshotted
    // at full opacity (see ../drag/sortable).
    beginDrag(event, row, {
      draggingClass: DRAGGING_CLASS,
      payload: row.dataset.positionedRowId
    })
  }

  #onDragOver(event) {
    // Without a cached row this is somebody else's drag (a kanban card, a file
    // from the desktop). Leave it alone so the browser shows "no entry" rather
    // than inviting a drop we would ignore.
    if (!this.draggedRow) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  #onDrop(event) {
    event.preventDefault()
    if (!this.draggedRow) return

    const row = this.draggedRow
    // Exclude the dragged row: an index computed over a list that still counts
    // the row being moved is off by one for every downward move.
    const others = this.#rows().filter(r => r !== row)
    const index = computeDropIndex(event.clientY, others)

    this.#applyMove(row, others, index)
  }

  #onDragEnd(_event) {
    if (!this.draggedRow) return

    endDrag(this.draggedRow, { draggingClass: DRAGGING_CLASS })
    this.draggedRow = null
  }

  // ─── keyboard ───────────────────────────────────────────────────────────────

  #onKeyDown(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return

    const grip = event.target.closest("[data-positioned-grip]")
    if (!grip) return

    const row = this.#rowFor(grip)
    if (!row) return

    // Only now: an arrow key that lands on nothing movable must keep its
    // native meaning (scrolling the page).
    event.preventDefault()

    const rows = this.#rows()
    const from = rows.indexOf(row)
    const to = event.key === "ArrowUp" ? from - 1 : from + 1
    if (to < 0 || to >= rows.length) return

    // With the row itself removed, "land at slot `to`" is the insertion index
    // among the remaining rows in both directions: up → to, down → to.
    const others = rows.filter(r => r !== row)
    this.#applyMove(row, others, to)

    // Moving a node in the DOM drops focus in most browsers, which would strand
    // the user after a single keypress. The grip travels with the row, so it is
    // still the right element to return to.
    grip.focus()
  }

  // ─── the move itself ────────────────────────────────────────────────────────

  // Moves `row` to `index` among `others` (which must already exclude `row`),
  // optimistically, then tells the server. Shared by drop and keyboard so the
  // two can never compute neighbours differently.
  #applyMove(row, others, index) {
    const before = others[index] ?? null
    const after = others[index - 1] ?? null

    // The row is already exactly there — both neighbours unchanged. A drop that
    // lands where it started is the commonest accidental drag there is, and
    // posting it would write a position identical to the current one (or, in
    // Mode B, run somebody else's renumbering block) for no reason at all.
    if (row.nextElementSibling === before && row.previousElementSibling === after) return

    row.parentElement.insertBefore(row, before)

    this.#submit(row.dataset.positionedRowId, {
      // The ids of the row's VISIBLE neighbours. A blank one means "nothing on
      // that side of my page" — the server treats that as a claim about the
      // viewport, not about the positioning group, and looks the real boundary
      // neighbour up itself (see PositionActions#resolve_position_boundaries).
      prevId: after?.dataset.positionedRowId ?? "",
      nextId: before?.dataset.positionedRowId ?? "",
      toIndex: index
    })
  }

  async #submit(recordId, { prevId, nextId, toIndex }) {
    // window.location.search is LOAD-BEARING, not decoration. The endpoint
    // re-renders through the ordinary index pipeline, so the collection's own
    // query — search, filters, scope, sort, page, view — has to arrive in
    // params. Without it a drop on page 3 of a filtered list reconciles as
    // page 1 of an unfiltered one.
    const url = this.urlTemplateValue.replace("__ID__", recordId) + window.location.search
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content ?? ""

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken
        },
        body: new URLSearchParams({
          prev_id: prevId,
          next_id: nextId,
          to_index: toIndex
        }),
        credentials: "same-origin"
      })

      // 204 = a clean drop. The optimistic DOM is already exactly right, so
      // repainting would only cost a flash and the user's focus.
      if (response.status === 204) return

      // Everything else the server answers with is a turbo-stream that replaces
      // the collection with its own truth — the row snaps back on a rejection,
      // or settles into a rebalanced order. Only feed Turbo genuine streams: a
      // 302 to a login page comes back as a 200 HTML document, and morphing
      // THAT into the table paints the error page over the collection.
      const contentType = response.headers.get("Content-Type") || ""
      if (contentType.includes("text/vnd.turbo-stream.html") && window.Turbo) {
        const focusedRowId = this.#focusedRowId()
        window.Turbo.renderStreamMessage(await response.text())
        // The stream replaced the rows, so a grip the user was tabbed to is
        // gone. Put focus back on the same record's new grip.
        if (focusedRowId) this.#restoreFocus(focusedRowId)
      } else if (!response.ok) {
        console.error(`[positioned] reposition rejected (${response.status}); leaving the row where it was dropped`)
      } else {
        console.warn("[positioned] reposition returned a non-stream response (session expired?); leaving the row where it was dropped")
      }
    } catch (error) {
      console.error("[positioned] reposition request failed:", error)
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  #rows() {
    return [...this.element.querySelectorAll("[data-positioned-row-id]")]
  }

  #rowFor(element) {
    return element.closest("[data-positioned-row-id]")
  }

  #focusedRowId() {
    const grip = document.activeElement?.closest?.("[data-positioned-grip]")
    return grip ? this.#rowFor(grip)?.dataset.positionedRowId : null
  }

  // Deferred a frame: renderStreamMessage resolves its render asynchronously,
  // so the replacement rows are not in the document yet when it returns.
  #restoreFocus(rowId) {
    requestAnimationFrame(() => {
      this.element
        .querySelector(`[data-positioned-row-id="${CSS.escape(rowId)}"] [data-positioned-grip]`)
        ?.focus()
    })
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="kanban"
//
// Enables drag-and-drop reordering of kanban cards across columns using the
// browser's native HTML5 drag-and-drop API (no additional npm dependency).
//
// ## DOM contract
//
// Board wrapper (this element):
//   data-controller="kanban"
//   data-kanban-move-url-template-value="/path/__ID__/kanban_move"
//     — the collection path with an __ID__ placeholder; the controller
//       substitutes the dragged card's record id at drop time.
//
// Column wrapper (rendered by Kanban::Column as the turbo-frame body):
//   data-kanban-col="<key>"            — unique wrapper identifier for JS
//   data-kanban-accepts="all|none|<key>,<key>,…"
//     — "all": any card may be dropped here
//     — "none": no card may be dropped here
//     — comma list: only cards whose source column key is in the list
//   data-kanban-locked="true|false"
//     — true: cards in this column cannot be dragged out of it
//
// Column drop zone (rendered by Kanban::Column inside each turbo-frame):
//   data-kanban-target="column"
//   data-kanban-column-key-value="<key>"
//
// Draggable card (rendered by Kanban::Card):
//   draggable="true"
//   data-kanban-record-id="<id>"
//   data-kanban-column-key="<source-column-key>"
//
// Column toggle control (button inside the strip / expanded header):
//   data-action="click->kanban#toggleColumn"
//   data-kanban-column-key="<key>"
//
// ## Collapse toggle
//
// toggleColumn reads data-kanban-column-key from the clicked button, finds
// the matching [data-kanban-col] wrapper, and flips the CSS class
// `pu-kanban-column-collapsed` on it. CSS handles show/hide of strip vs body.
// The per-column state is persisted in localStorage keyed by the resource
// path + column key so the preference survives page reloads.
//
// On connect() the controller reads all persisted states and applies them
// before the first paint (wrappers are present in the DOM when the turbo-frame
// content loads; Stimulus's MutationObserver reconnects after each frame swap).
//
// ## Drop hints
//
// On dragstart:
//   1. Determine whether the source column is locked (cards cannot leave).
//   2. For each column wrapper, compute whether a drop would be accepted and
//      add the CSS class `pu-kanban-no-drop` to wrappers that would reject.
//   3. Also suppress the browser's `dragover` preventDefault() for no-drop
//      columns so the native "no entry" cursor shows.
// On dragend: clear all hint classes.
//
// ## Move flow
//
// 1. dragstart — record which card was grabbed and apply an opacity hint.
// 2. dragover  — highlight the target column drop zone; suppress the browser's
//                "forbidden" cursor by calling preventDefault(). For columns
//                marked pu-kanban-no-drop we skip preventDefault so the native
//                "no entry" cursor shows instead.
// 3. drop      — compute to_index (vertical cursor position within the column),
//                POST {from_column, to_column, to_index} to the move endpoint,
//                and feed the Turbo Stream response to Turbo.renderStreamMessage.
//                On success the server re-renders both column frames; on 422 it
//                re-renders only the source column so the card snaps back — the
//                controller never hand-manages rollback state.
// 4. dragend   — clean up opacity + highlights + drop-hint classes.
export default class extends Controller {
  static values = { moveUrlTemplate: String }
  static targets = ["column"]

  connect() {
    this.draggedCard = null

    this.onDragStart = this.#onDragStart.bind(this)
    this.onDragOver = this.#onDragOver.bind(this)
    this.onDragLeave = this.#onDragLeave.bind(this)
    this.onDrop = this.#onDrop.bind(this)
    this.onDragEnd = this.#onDragEnd.bind(this)

    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragover", this.onDragOver)
    this.element.addEventListener("dragleave", this.onDragLeave)
    this.element.addEventListener("drop", this.onDrop)
    this.element.addEventListener("dragend", this.onDragEnd)

    // Apply any persisted collapse states from localStorage so columns
    // retain the user's preference across page reloads.
    this.#applyPersistedCollapseStates()
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragover", this.onDragOver)
    this.element.removeEventListener("dragleave", this.onDragLeave)
    this.element.removeEventListener("drop", this.onDrop)
    this.element.removeEventListener("dragend", this.onDragEnd)
  }

  // ─── Collapse toggle ─────────────────────────────────────────────────────────

  // Stimulus action: data-action="click->kanban#toggleColumn"
  // Expected on the expand button in the collapsed strip and the collapse
  // button in the expanded header.  data-kanban-column-key on the button
  // identifies which column to toggle.
  toggleColumn(event) {
    const key = event.currentTarget.dataset.kanbanColumnKey
    if (!key) return

    const wrapper = this.element.querySelector(`[data-kanban-col="${key}"]`)
    if (!wrapper) return

    const strip = wrapper.querySelector("[data-kanban-role='strip']")
    const body  = wrapper.querySelector("[data-kanban-role='body']")
    if (!strip || !body) return

    // `pu-kanban-column-collapsed` on the wrapper is what CSS uses to decide
    // which half to show. Toggling the class is the only state mutation.
    const isCollapsed = wrapper.classList.contains("pu-kanban-column-collapsed")

    if (isCollapsed) {
      wrapper.classList.remove("pu-kanban-column-collapsed")
      this.#saveCollapseState(key, false)
    } else {
      wrapper.classList.add("pu-kanban-column-collapsed")
      this.#saveCollapseState(key, true)
    }
  }

  // ─── drag lifecycle ──────────────────────────────────────────────────────────

  #onDragStart(event) {
    const card = event.target.closest("[data-kanban-record-id]")
    if (!card) return

    this.draggedCard = card
    event.dataTransfer.effectAllowed = "move"
    // Store the id so native DnD still carries data if the card is dropped
    // outside the board (where we won't handle it, but no error).
    event.dataTransfer.setData("text/plain", card.dataset.kanbanRecordId)

    // Defer the opacity change so the drag ghost image is captured first.
    requestAnimationFrame(() => card.classList.add("pu-kanban-dragging"))

    // Mark columns that would reject a drop from this card's source column.
    this.#applyDropHints(card.dataset.kanbanColumnKey)
  }

  #onDragOver(event) {
    const column = event.target.closest("[data-kanban-target='column']")
    if (!column) return

    // Skip preventDefault for no-drop columns so the browser shows a
    // "no entry" cursor rather than the move cursor.
    const wrapper = event.target.closest("[data-kanban-col]")
    if (wrapper?.classList.contains("pu-kanban-no-drop")) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.#highlightColumn(column)
  }

  #onDragLeave(event) {
    // Only clear the highlight when the cursor leaves the board entirely.
    // relatedTarget is null when leaving the viewport, or a node outside
    // the board wrapper when crossing the edge.
    if (!this.element.contains(event.relatedTarget)) {
      this.#clearHighlights()
    }
  }

  async #onDrop(event) {
    event.preventDefault()
    this.#clearHighlights()

    if (!this.draggedCard) return

    // Respect client-side drop hints: skip the POST for columns the client
    // knows would reject. The server enforces this authoritatively on every
    // request, so skipping saves a round-trip and avoids a 422 flash.
    const wrapper = event.target.closest("[data-kanban-col]")
    if (wrapper?.classList.contains("pu-kanban-no-drop")) return

    const column = event.target.closest("[data-kanban-target='column']")
    if (!column) return

    const recordId = this.draggedCard.dataset.kanbanRecordId
    const fromColumn = this.draggedCard.dataset.kanbanColumnKey
    const toColumn = column.dataset.kanbanColumnKeyValue

    // Cards currently in the destination column, excluding the dragged card
    // itself (it may already be there for a same-column reorder).
    const existingCards = [...column.querySelectorAll("[data-kanban-record-id]")]
      .filter(c => c !== this.draggedCard)

    const toIndex = this.#computeDropIndex(event.clientY, existingCards)
    const url = this.moveUrlTemplateValue.replace("__ID__", recordId)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content ?? ""

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken,
        },
        body: new URLSearchParams({
          from_column: fromColumn,
          to_column: toColumn,
          to_index: toIndex,
        }),
        credentials: "same-origin",
      })

      const body = await response.text()
      // Turbo.renderStreamMessage processes <turbo-stream> elements in the
      // response body. On success this re-renders the from + to column frames;
      // on 422 it re-renders only the source frame, snapping the card back.
      if (window.Turbo) {
        Turbo.renderStreamMessage(body)
      }
    } catch (error) {
      console.error("[kanban] move request failed:", error)
    }
  }

  #onDragEnd(_event) {
    this.#clearHighlights()
    this.#clearDropHints()
    if (this.draggedCard) {
      this.draggedCard.classList.remove("pu-kanban-dragging")
      this.draggedCard = null
    }
  }

  // ─── drop hints ──────────────────────────────────────────────────────────────

  // Marks each column wrapper with `pu-kanban-no-drop` when it would refuse
  // a card dragged from sourceKey. The server remains the authority; this
  // is a display-only hint to give the user immediate visual feedback.
  #applyDropHints(sourceKey) {
    // If the source column is locked, no card can leave it — all targets are
    // effectively invalid.
    const sourceWrapper = this.element.querySelector(`[data-kanban-col="${sourceKey}"]`)
    const sourceLocked = sourceWrapper?.dataset.kanbanLocked === "true"

    this.element.querySelectorAll("[data-kanban-col]").forEach(wrapper => {
      const noDrop = sourceLocked || !this.#columnAccepts(wrapper.dataset.kanbanAccepts, sourceKey)
      wrapper.classList.toggle("pu-kanban-no-drop", noDrop)
    })
  }

  #clearDropHints() {
    this.element.querySelectorAll("[data-kanban-col]")
      .forEach(w => w.classList.remove("pu-kanban-no-drop"))
  }

  // Returns true if the column described by `accepts` (the serialised form
  // from data-kanban-accepts) would accept a card from `sourceKey`.
  #columnAccepts(accepts, sourceKey) {
    if (!accepts || accepts === "all") return true
    if (accepts === "none") return false
    return accepts.split(",").map(k => k.trim()).includes(sourceKey)
  }

  // ─── collapse persistence ─────────────────────────────────────────────────────

  // Applies localStorage collapse states to all column wrappers currently in
  // the DOM. Called on connect() and implicitly after Turbo frame swaps
  // because Stimulus re-connects the controller when the frame content changes.
  #applyPersistedCollapseStates() {
    this.element.querySelectorAll("[data-kanban-col]").forEach(wrapper => {
      const key = wrapper.dataset.kanbanCol
      const stored = localStorage.getItem(this.#storageKey(key))
      if (stored === null) return  // No stored preference; use server-rendered initial state.

      const collapsed = stored === "1"
      wrapper.classList.toggle("pu-kanban-column-collapsed", collapsed)
    })
  }

  #saveCollapseState(key, collapsed) {
    // Safari private-browsing reports a 0-byte quota and throws
    // QuotaExceededError on setItem. Swallow it so the toggle still works
    // visually — it just won't persist across reloads in that mode.
    try {
      localStorage.setItem(this.#storageKey(key), collapsed ? "1" : "0")
    } catch { /* private browsing: toggle still works, just won't persist */ }
  }

  // Derives a unique localStorage key from the resource collection path so
  // different boards (different resources / tenants) don't share state.
  // The move URL template is "/path/__ID__/kanban_move"; strip the suffix to
  // recover the collection path.
  #storageKey(key) {
    const path = this.moveUrlTemplateValue.replace("/__ID__/kanban_move", "")
    return `pu-kanban:${path}:${key}:collapsed`
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  // Returns the 0-based insertion index within the destination column by
  // comparing the cursor y-position against each card's vertical midpoint.
  // The card is inserted before the first card whose midpoint is below the
  // cursor, or appended after all cards if the cursor is below every midpoint.
  #computeDropIndex(clientY, cards) {
    for (let i = 0; i < cards.length; i++) {
      const rect = cards[i].getBoundingClientRect()
      if (clientY < rect.top + rect.height / 2) return i
    }
    return cards.length
  }

  #highlightColumn(column) {
    this.columnTargets.forEach(c => {
      c.classList.toggle("pu-kanban-drop-target", c === column)
    })
  }

  #clearHighlights() {
    this.columnTargets.forEach(c => c.classList.remove("pu-kanban-drop-target"))
  }
}

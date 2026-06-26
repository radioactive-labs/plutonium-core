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
// Column drop zone (rendered by Kanban::Column inside each turbo-frame):
//   data-kanban-target="column"
//   data-kanban-column-key-value="<key>"
//
// Draggable card (rendered by Kanban::Card):
//   draggable="true"
//   data-kanban-record-id="<id>"
//   data-kanban-column-key="<source-column-key>"
//
// ## Move flow
//
// 1. dragstart — record which card was grabbed and apply an opacity hint.
// 2. dragover  — highlight the target column drop zone; suppress the browser's
//                "forbidden" cursor by calling preventDefault().
// 3. drop      — compute to_index (vertical cursor position within the column),
//                POST {from_column, to_column, to_index} to the move endpoint,
//                and feed the Turbo Stream response to Turbo.renderStreamMessage.
//                On success the server re-renders both column frames; on 422 it
//                re-renders only the source column so the card snaps back — the
//                controller never hand-manages rollback state.
// 4. dragend   — clean up opacity + highlights regardless of outcome.
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
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragover", this.onDragOver)
    this.element.removeEventListener("dragleave", this.onDragLeave)
    this.element.removeEventListener("drop", this.onDrop)
    this.element.removeEventListener("dragend", this.onDragEnd)
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
  }

  #onDragOver(event) {
    const column = event.target.closest("[data-kanban-target='column']")
    if (!column) return

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

    const column = event.target.closest("[data-kanban-target='column']")
    if (!column || !this.draggedCard) return

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
    if (this.draggedCard) {
      this.draggedCard.classList.remove("pu-kanban-dragging")
      this.draggedCard = null
    }
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

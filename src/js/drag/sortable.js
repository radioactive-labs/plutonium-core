// Shared native HTML5 drag-and-drop mechanics.
//
// Deliberately knows nothing about kanban columns, tables, WIP limits, or
// Turbo. Consumers wire it to their own DOM contract and own the transport
// (which element is draggable, what a "drop" means, what gets POSTed where).
//
// Everything here is a pure function over an event / element / geometry — no
// module state, so two controllers can be live on the same page without
// interfering.
//
// Consumers: kanban_controller.js, positioned_controller.js

// Returns the 0-based insertion index for a drop at `clientY` among `items`,
// by comparing the cursor against each item's vertical midpoint: the drop goes
// BEFORE the first item whose midpoint is below the cursor, or after all of
// them when the cursor is below every midpoint.
//
// `items` must already exclude the dragged element itself — otherwise a
// same-container reorder computes an index that counts the item being moved.
export function computeDropIndex(clientY, items) {
  for (let i = 0; i < items.length; i++) {
    const rect = items[i].getBoundingClientRect()
    if (clientY < rect.top + rect.height / 2) return i
  }
  return items.length
}

// Horizontal variant of the above, for grid / card layouts that flow in rows
// rather than stacking in a column.
//
// NOT dead code: it has no consumer yet — the grid view that uses it lands in a
// follow-up — but it ships alongside its vertical twin deliberately, because
// the pair is the whole point of this module and splitting them across commits
// invites the two from drifting.
export function computeDropIndexHorizontal(clientX, items) {
  for (let i = 0; i < items.length; i++) {
    const rect = items[i].getBoundingClientRect()
    if (clientX < rect.left + rect.width / 2) return i
  }
  return items.length
}

// Applies the drag payload + the dragging class to `element`.
//
// The class change is deferred one frame ON PURPOSE: the browser captures the
// drag ghost image from the element's rendered state during dragstart, so
// adding an opacity class synchronously produces an already-faded ghost. One
// requestAnimationFrame is enough for the ghost to be snapshotted first and the
// source element to then dim in place.
//
// `payload` is written to text/plain so a drop OUTSIDE the consumer's own
// container still carries data natively instead of erroring.
export function beginDrag(event, element, { draggingClass, payload }) {
  event.dataTransfer.effectAllowed = "move"
  event.dataTransfer.setData("text/plain", payload)

  requestAnimationFrame(() => element.classList.add(draggingClass))
}

// Undoes beginDrag's visual half. Callers own the rest of their teardown
// (highlights, hints, cached references) — this only knows about the class it
// added.
export function endDrag(element, { draggingClass }) {
  element.classList.remove(draggingClass)
}

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
// Scoped to ONE visual row. A wrapped grid gives every row the same left edge,
// so an X comparison across rows is meaningless — the caller narrows to a row
// first and passes only that row's items (see positioned_controller's
// #dropIndex, which does exactly that).
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
// `dragImage` names the element the browser should ghost. Pass it whenever the
// draggable node is a HANDLE inside the thing being moved rather than the thing
// itself: the browser ghosts whatever carries draggable="true", so a table's
// grip button drags a picture of the grip and the row appears not to move at
// all. Consumers whose whole element is draggable (a kanban card) can omit it —
// the default ghost is already the right picture.
export function beginDrag(event, element, { draggingClass, payload, dragImage = null }) {
  event.dataTransfer.effectAllowed = "move"
  event.dataTransfer.setData("text/plain", payload)

  if (dragImage) {
    // Anchor the ghost where the pointer actually grabbed, so it tracks under
    // the cursor instead of snapping its corner to it.
    const rect = dragImage.getBoundingClientRect()
    event.dataTransfer.setDragImage(dragImage, event.clientX - rect.left, event.clientY - rect.top)
  }

  requestAnimationFrame(() => element.classList.add(draggingClass))
}

// Undoes beginDrag's visual half. Callers own the rest of their teardown
// (highlights, hints, cached references) — this only knows about the class it
// added, plus the insertion marker, which no caller should have to remember to
// clean up separately.
export function endDrag(element, { draggingClass }) {
  element.classList.remove(draggingClass)
  hideInsertionMarker()
}

// ─── insertion marker ────────────────────────────────────────────────────────
//
// A line showing WHERE the drop will land. Without it the only feedback during
// a drag is the ghost following the cursor, which says what you are moving but
// never where it will end up — the user is guessing until they release.
//
// One marker element, created lazily and reused, parked on <body> and
// positioned in viewport coordinates (position: fixed). Deliberately NOT
// inserted between the items it points at: a table would need a full-width
// placeholder <tr> to sit between rows, and mutating the collection's own DOM
// mid-drag fights the Turbo stream that replaces it on drop.

const MARKER_ID = "pu-drag-insertion-marker"

function insertionMarker() {
  let marker = document.getElementById(MARKER_ID)
  if (!marker) {
    marker = document.createElement("div")
    marker.id = MARKER_ID
    marker.className = "pu-drag-marker"
    // Decorative: it duplicates information the drag itself conveys, and a
    // live region announcing every dragover would flood a screen reader.
    marker.setAttribute("aria-hidden", "true")
    document.body.appendChild(marker)
  }
  return marker
}

// Draws the marker at insertion point `index` within `items` — the same index
// computeDropIndex/computeDropIndexHorizontal return, so the line always agrees
// with where the drop actually goes.
//
// `items` must exclude the dragged element, exactly as it does for the index
// computation. `axis` is "vertical" for stacked rows/cards (a horizontal rule
// between them) and "horizontal" for grids (a vertical rule between cards).
// `container` is the fallback for an empty target — an empty kanban column
// still needs to say "it lands here".
export function showInsertionMarker(items, index, { axis = "vertical", container = null } = {}) {
  const marker = insertionMarker()

  let rect
  let leading
  if (items.length === 0) {
    if (!container) return hideInsertionMarker()
    rect = container.getBoundingClientRect()
    leading = true
  } else if (index < items.length) {
    rect = items[index].getBoundingClientRect()
    leading = true
  } else {
    // Past the end: hug the trailing edge of the last item.
    rect = items[items.length - 1].getBoundingClientRect()
    leading = false
  }

  if (axis === "horizontal") {
    marker.style.left = `${leading ? rect.left : rect.right}px`
    marker.style.top = `${rect.top}px`
    marker.style.height = `${rect.height}px`
    marker.style.width = ""
  } else {
    marker.style.left = `${rect.left}px`
    marker.style.top = `${leading ? rect.top : rect.bottom}px`
    marker.style.width = `${rect.width}px`
    marker.style.height = ""
  }

  marker.dataset.axis = axis
  marker.style.display = "block"
}

export function hideInsertionMarker() {
  const marker = document.getElementById(MARKER_ID)
  if (marker) marker.style.display = "none"
}

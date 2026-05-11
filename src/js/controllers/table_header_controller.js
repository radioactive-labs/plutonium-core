import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table-header"
// Routes column-header clicks: shift-click navigates to multi-href instead of href,
// adding the column to the existing sort stack (multi-sort).
// Plain click lets the default link navigation happen, which replaces all sorts.
export default class extends Controller {
  headerClick(event) {
    if (!event.shiftKey) return // plain click: let the link navigate normally
    const link = event.currentTarget
    const multiHref = link.dataset.tableHeaderMultiHref
    if (!multiHref) return
    event.preventDefault()
    Turbo.visit(multiHref)
  }
}

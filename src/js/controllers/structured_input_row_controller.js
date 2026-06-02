import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="structured-input-row"
//
// Soft-removes a classless structured-input row by DISABLING its fields — a
// disabled <fieldset> is omitted from form submission, so the server simply
// receives the payload without that row and rebuilds the JSON column from what
// it gets (no _destroy marker needed). The row stays in the DOM, collapsed to a
// "Removed — Restore" bar, so it can be restored (re-enabled) before saving.
export default class extends Controller {
  static targets = ["content", "removed"]

  remove(e) {
    e.preventDefault()
    this.contentTarget.disabled = true
    this.contentTarget.hidden = true
    this.removedTarget.hidden = false
  }

  restore(e) {
    e.preventDefault()
    this.contentTarget.disabled = false
    this.contentTarget.hidden = false
    this.removedTarget.hidden = true
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="wizard"
//
// Lightweight glue for the wizard step page. Navigation itself is plain HTML —
// each Back/Next/Finish/Cancel button submits with its own `name="_direction"`
// value, so the wizard works without JavaScript. This controller only:
//
//   - exposes the hidden `_direction` field (the `direction` target) so future
//     client-side affordances (e.g. an autosave or a "save & exit") can set the
//     direction before submitting;
//   - guards against a double submit once a nav button has been pressed.
export default class extends Controller {
  static targets = ["direction"]

  connect() {
    this.submitting = false
    this.element.addEventListener("submit", this.onSubmit)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.onSubmit)
  }

  // Set the hidden `_direction` value programmatically (optional helper).
  setDirection(value) {
    if (this.hasDirectionTarget) this.directionTarget.value = value
  }

  onSubmit = (event) => {
    if (this.submitting) {
      event.preventDefault()
      return
    }
    this.submitting = true
    // Re-enable after Turbo restores the page (back/forward cache) so a later
    // submit isn't permanently blocked.
    setTimeout(() => {
      this.submitting = false
    }, 0)
  }
}

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
    // Re-enable when the submission's request SETTLES (success or failure), so a
    // real later submit works while a double-click mid-flight stays blocked. A
    // bare setTimeout(0) fired on the next tick — sub-millisecond, long before a
    // human's second click — so it never actually guarded a double-click.
    this.element.addEventListener("turbo:submit-end", this.onSettled)
    // A non-Turbo full-page submit navigates away; on a Turbo back/forward
    // (bfcache) restore the cached form returns with `submitting` still set —
    // clear it so the restored page is usable.
    document.addEventListener("turbo:load", this.onSettled)
    window.addEventListener("pageshow", this.onSettled)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.onSubmit)
    this.element.removeEventListener("turbo:submit-end", this.onSettled)
    document.removeEventListener("turbo:load", this.onSettled)
    window.removeEventListener("pageshow", this.onSettled)
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
  }

  onSettled = () => {
    this.submitting = false
  }
}

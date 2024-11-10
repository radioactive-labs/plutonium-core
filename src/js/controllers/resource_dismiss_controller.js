import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resource-dismiss"
export default class extends Controller {
  static values = {
    after: Number,
  }

  connect() {
    console.log(`resource-dismiss connected: ${this.element}`)

    if (this.hasAfterValue && this.afterValue > 0) {
      this.autoDismissTimeout = setTimeout(() => {
        this.dismiss()
        this.autoDismissTimeout = null
      }, this.afterValue);
    }
  }

  disconnect() {
    if (this.autoDismissTimeout) clearTimeout(this.autoDismissTimeout)

    this.autoDismissTimeout = null
  }

  dismiss() {
    this.element.remove()
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slim-select"
export default class extends Controller {
  connect() {
    this.slimSelect = new SlimSelect({
      select: this.element
    })
    this.element.setAttribute("data-action", "turbo:morph-element->slim-select#reconnect")
  }

  disconnect() {
    if (this.slimSelect) {
      this.slimSelect.destroy()
      this.slimSelect = null
    }
  }

  reconnect() {
    this.disconnect()
    // dispatch this on the next frame.
    // there's some funny issue where my elements get removed from the DOM
    setTimeout(() => this.connect(), 10)
  }
}

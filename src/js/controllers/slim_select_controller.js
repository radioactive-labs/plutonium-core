import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slim-select"
export default class extends Controller {
  connect() {
    console.log(`slim-select connected: ${this.element}`)
    this.slimSelect = new SlimSelect({
      select: this.element
    })
    this.element.setAttribute("data-action", "turbo:morph-element->slim-select#reconnect")
  }

  disconnect() {
    this.slimSelect.destroy()
    this.slimSelect = null
  }

  reconnect() {
    this.disconnect()
    this.connect()
  }
}

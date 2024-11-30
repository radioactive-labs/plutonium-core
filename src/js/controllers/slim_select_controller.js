import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slim-select"
export default class extends Controller {
  connect() {
    console.log(`slim-select connected: ${this.element}`)
    self.slimSelect = new SlimSelect({
      select: this.element
    })
    this.element.setAttribute("data-action", "turbo:morph-element->slim-select#reconnect")
  }

  disconnect() {
    self.slimSelect.destroy()
    self.slimSelect = null
  }

  reconnect() {
    this.disconnect()
    this.connect()
  }
}

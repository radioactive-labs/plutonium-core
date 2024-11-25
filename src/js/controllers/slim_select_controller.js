import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slim-select"
export default class extends Controller {
  connect() {
    console.log(`slim-select connected: ${this.element}`)
    self.slimSelect = new SlimSelect({
      select: this.element
    })
  }

  disconnect() {
    self.slimSelect.destroy()
    self.slimSelect = null
  }
}

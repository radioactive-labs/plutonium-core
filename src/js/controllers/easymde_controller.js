import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="easymde"
export default class extends Controller {
  connect() {
    console.log(`easymde connected: ${this.element}`)
    self.easyMDE = new EasyMDE({ element: this.element })
  }

  disconnect() {
    self.easyMDE.toTextArea()
    self.easyMDE = null
  }
}

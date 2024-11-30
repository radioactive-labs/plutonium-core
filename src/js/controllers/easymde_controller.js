import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="easymde"
export default class extends Controller {
  connect() {
    console.log(`easymde connected: ${this.element}`)
    self.easyMDE = new EasyMDE({ element: this.element })
    this.element.setAttribute("data-action", "turbo:morph-element->easymde#reconnect")
  }

  disconnect() {
    self.easyMDE.toTextArea()
    self.easyMDE = null
  }

  reconnect() {
    this.disconnect()
    this.connect()
  }
}

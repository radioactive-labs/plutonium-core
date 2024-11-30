import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="easymde"
export default class extends Controller {
  connect() {
    console.log(`easymde connected: ${this.element}`)
    self.easyMDE = new EasyMDE(this.#buildOptions())
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

  #buildOptions() {
    let options = { element: this.element }
    if (this.element.attributes.id.value) {
      options.autosave = {
        enabled: true,
        uniqueId: this.element.attributes.id.value,
        delay: 1000,
      }
    }
    return options
  }
}

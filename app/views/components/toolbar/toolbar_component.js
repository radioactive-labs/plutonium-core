import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toolbar"
export default class extends Controller {
  connect() {
    console.log(`toolbar connected: ${this.element}`)
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resource-header"
export default class extends Controller {
  connect() {
    console.log(`resource-header connected: ${this.element}`)
  }
}

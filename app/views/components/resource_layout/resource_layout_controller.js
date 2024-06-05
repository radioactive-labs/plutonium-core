import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resource-layout"
export default class extends Controller {
  connect() {
    console.log(`resource-layout connected: ${this.element}`)
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="has-many-panel"
export default class extends Controller {
  connect() {
    console.log(`has-many-panel connected: ${this.element}`)
  }
}

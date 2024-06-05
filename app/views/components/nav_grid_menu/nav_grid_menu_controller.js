import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-grid-menu"
export default class extends Controller {
  connect() {
    console.log(`nav-grid-menu connected: ${this.element}`)
  }
}

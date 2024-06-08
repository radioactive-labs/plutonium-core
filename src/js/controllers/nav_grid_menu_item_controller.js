import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-grid-menu-item"
export default class extends Controller {
  connect() {
    console.log(`nav-grid-menu-item connected: ${this.element}`)
  }
}

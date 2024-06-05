import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-user-section"
export default class extends Controller {
  connect() {
    console.log(`nav-user-section connected: ${this.element}`)
  }
}

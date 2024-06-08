import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-user-link"
export default class extends Controller {
  connect() {
    console.log(`nav-user-link connected: ${this.element}`)
  }
}

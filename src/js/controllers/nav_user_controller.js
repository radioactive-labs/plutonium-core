import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-user"
export default class extends Controller {
  connect() {
    console.log(`nav-user connected: ${this.element}`)
  }
}

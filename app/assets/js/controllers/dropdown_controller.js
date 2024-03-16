import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  connect() {
    console.log(`form connected: ${this.element}`)
  }

  submit() {
    this.element.requestSubmit()
  }
}

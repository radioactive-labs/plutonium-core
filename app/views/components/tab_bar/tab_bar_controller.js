import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tab-bar"
export default class extends Controller {
  connect() {
    console.log(`tab-bar connected: ${this.element}`)
  }
}

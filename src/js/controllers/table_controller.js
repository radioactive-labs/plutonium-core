import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table"
export default class extends Controller {
  connect() {
    console.log(`table connected: ${this.element}`)
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table-toolbar"
export default class extends Controller {
  connect() {
    console.log(`table-toolbar connected: ${this.element}`)
  }
}

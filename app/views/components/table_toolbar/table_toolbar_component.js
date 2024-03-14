import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table_toolbar"
export default class extends Controller {
  connect() {
    console.log(`table_toolbar connected: ${this.element}`)
  }
}

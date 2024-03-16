import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table-search-input"
export default class extends Controller {
  connect() {
    console.log(`table-search-input connected: ${this.element}`)
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table_search_input"
export default class extends Controller {
  connect() {
    console.log(`table_search_input connected: ${this.element}`)
  }
}

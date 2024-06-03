import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar-menu"
export default class extends Controller {
  connect() {
    console.log(`sidebar-menu connected: ${this.element}`)
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar-menu-item"
export default class extends Controller {
  connect() {
    console.log(`sidebar-menu-item connected: ${this.element}`)
  }
}

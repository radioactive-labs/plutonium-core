import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="attachment-preview-container"
export default class extends Controller {
  connect() {
  }

  append(element) {
    this.element.appendChild(element)
  }

  clear() {
    this.element.innerHTML = null
  }
}

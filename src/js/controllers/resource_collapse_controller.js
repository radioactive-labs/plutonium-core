import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resource-collapse"
export default class extends Controller {
  static targets = ["trigger", "menu"]

  connect() {
    console.log(`resource-collapse connected: ${this.element}`)

    // Default to false if the data attribute isn't set
    if (!this.element.hasAttribute('data-visible')) {
      this.element.setAttribute('data-visible', 'false')
    }

    // Set initial state
    this.#updateState()
  }

  toggle() {
    const isVisible = this.element.getAttribute('data-visible') === 'true'
    this.element.setAttribute('data-visible', (!isVisible).toString())
    this.#updateState()
  }

  #updateState() {
    const isVisible = this.element.getAttribute('data-visible') === 'true'

    if (isVisible) {
      this.menuTarget.classList.remove('hidden')
      this.triggerTarget.setAttribute('aria-expanded', 'true')
      this.dispatch('expand')
    } else {
      this.menuTarget.classList.add('hidden')
      this.triggerTarget.setAttribute('aria-expanded', 'false')
      this.dispatch('collapse')
    }
  }
}

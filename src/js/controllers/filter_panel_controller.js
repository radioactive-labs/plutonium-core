import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-panel"
export default class extends Controller {
  clear() {
    this.element.querySelectorAll('input, select, textarea').forEach(input => {
      if (input.type === 'checkbox' || input.type === 'radio') {
        input.checked = false
      } else if (input.tagName === 'SELECT') {
        input.selectedIndex = 0
      } else if (input.type === 'hidden') {
        // Clear hidden inputs that are filter values (e.g., flatpickr)
        if (input.dataset.controller === 'flatpickr') {
          input.value = ''
        }
      } else {
        input.value = ''
      }
    })

    // Clear flatpickr instances via Stimulus controller
    this.element.querySelectorAll('[data-controller="flatpickr"]').forEach(input => {
      const controller = this.application.getControllerForElementAndIdentifier(input, 'flatpickr')
      if (controller?.picker) {
        controller.picker.clear()
      }
    })

    // Submit the parent form
    const form = this.element.closest('form')
    if (form) {
      form.requestSubmit()
    }
  }
}

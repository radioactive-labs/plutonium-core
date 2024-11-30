import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flatpickr"
export default class extends Controller {
  connect() {
    console.log(`flatpickr connected: ${this.element}`)
    self.picker = new flatpickr(this.element, this.#buildOptions())
  }

  disconnect() {
    self.picker.destroy()
    self.picker = null
  }

  #buildOptions() {
    let options = { altInput: true }
    if (this.element.attributes.type.value == "datetime-local") {
      options.enableTime = true
    }
    else if (this.element.attributes.type.value == "time") {
      options.enableTime = true
      options.noCalendar = true
      // options.time_24hr = true
      // options.altFormat = "H:i"
    }
    return options
  }
}

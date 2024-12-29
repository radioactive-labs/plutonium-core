import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flatpickr"
export default class extends Controller {
  connect() {
    this.picker = new flatpickr(this.element, this.#buildOptions())
    this.element.setAttribute("data-action", "turbo:morph-element->flatpickr#reconnect")
  }

  disconnect() {
    this.picker.destroy()
    this.picker = null
  }

  reconnect() {
    this.disconnect()
    this.connect()
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

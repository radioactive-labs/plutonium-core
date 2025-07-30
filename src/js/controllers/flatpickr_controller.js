import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="flatpickr"
export default class extends Controller {
  connect() {
    if (this.picker) return;

    this.modal = document.querySelector("[data-controller=remote-modal]");
    this.picker = new flatpickr(this.element, this.#buildOptions());

    // Just recreate Flatpickr after morphing - the DOM will have correct value
    this.element.addEventListener("turbo:morph-element", (event) => {
      if (event.target === this.element && !this.morphing) {
        this.morphing = true;
        requestAnimationFrame(() => {
          this.#handleMorph();
          this.morphing = false;
        });
      }
    });
  }

  disconnect() {
    if (this.picker) {
      this.picker.destroy();
      this.picker = null;
    }
  }

  #handleMorph() {
    if (!this.element.isConnected) return;

    // Clean up the old instance
    if (this.picker) {
      this.picker.destroy();
      this.picker = null;
    }

    // Recreate the picker - it will pick up the current DOM value
    this.modal = document.querySelector("[data-controller=remote-modal]");
    this.picker = new flatpickr(this.element, this.#buildOptions());
  }

  #buildOptions() {
    let options = { altInput: true };

    if (this.element.attributes.type.value == "datetime-local") {
      options.enableTime = true;
    } else if (this.element.attributes.type.value == "time") {
      options.enableTime = true;
      options.noCalendar = true;
      // options.time_24hr = true
      // options.altFormat = "H:i"
    }

    if (this.modal) {
      options.appendTo = this.modal;
    }

    return options;
  }
}

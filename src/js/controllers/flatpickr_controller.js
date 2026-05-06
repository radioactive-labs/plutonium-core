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
      // Inside a <dialog> opened via showModal(), the dialog establishes its
      // own containing block in the top layer. flatpickr's default positioning
      // computes document coordinates but the calendar (appended to the
      // dialog) interprets them relative to the dialog's box, placing the
      // calendar far from the input. Append to the modal and reposition
      // manually relative to the modal's bounding rect.
      options.appendTo = this.modal;
      options.position = (instance) => {
        const input = instance.altInput || instance.input;
        const inputRect = input.getBoundingClientRect();
        const modalRect = this.modal.getBoundingClientRect();
        const cal = instance.calendarContainer;
        const calHeight = cal.offsetHeight;
        const spaceBelow = window.innerHeight - inputRect.bottom;
        const showAbove = spaceBelow < calHeight && inputRect.top > calHeight;
        const top = showAbove
          ? inputRect.top - modalRect.top - calHeight - 2
          : inputRect.bottom - modalRect.top + 2;
        cal.style.top = `${top}px`;
        cal.style.left = `${inputRect.left - modalRect.left}px`;
        cal.style.right = "auto";
        cal.classList.toggle("arrowTop", !showAbove);
        cal.classList.toggle("arrowBottom", showAbove);
      };
    }

    return options;
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="intl-tel-input"
export default class extends Controller {
  static targets = ["input"]

  connect() {
  }

  disconnect() {
    this.inputTargetDisconnected()
  }

  inputTargetConnected() {
    if (!this.hasInputTarget || this.iti) return;

    this.iti = window.intlTelInput(this.inputTarget, this.#buildOptions())

    // Just recreate IntlTelInput after morphing - the DOM will have correct value
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

  inputTargetDisconnected() {
    if (this.iti) {
      this.iti.destroy()
      this.iti = null
    }
  }

  #handleMorph() {
    if (!this.inputTarget || !this.inputTarget.isConnected) return;

    // Clean up the old instance
    if (this.iti) {
      this.iti.destroy();
      this.iti = null;
    }

    // Recreate the intl tel input - it will pick up the current DOM value
    this.iti = window.intlTelInput(this.inputTarget, this.#buildOptions());
  }

  #buildOptions() {
    return {
      strictMode: true,
      hiddenInput: () => ({ phone: this.inputTarget.attributes.name.value }),
      loadUtilsOnInit: "https://cdn.jsdelivr.net/npm/intl-tel-input@24.8.1/build/js/utils.js",
    }
  }
}

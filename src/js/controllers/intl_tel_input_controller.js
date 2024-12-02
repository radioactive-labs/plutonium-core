import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="intl-tel-input"
export default class extends Controller {
  static targets = ["input"]

  connect() {
    console.log(`intl-tel-input connected: ${this.element}`)
  }

  disconnect() {
    this.inputTargetDisconnected()
  }

  inputTargetConnected() {
    if (!this.hasInputTarget) return;

    this.iti = window.intlTelInput(this.inputTarget, this.#buildOptions())
    this.inputTarget.setAttribute("data-action", "turbo:morph-element->intl-tel-input#reconnect")
  }

  inputTargetDisconnected() {
    if (this.iti) this.iti.destroy()
    this.iti = null
  }

  reconnect() {
    this.inputTargetDisconnected()
    this.inputTargetConnected()
  }

  #buildOptions() {
    return {
      strictMode: true,
      hiddenInput: () => ({ phone: this.inputTarget.attributes.name.value }),
      loadUtilsOnInit: "https://cdn.jsdelivr.net/npm/intl-tel-input@24.8.1/build/js/utils.js",
    }
  }
}

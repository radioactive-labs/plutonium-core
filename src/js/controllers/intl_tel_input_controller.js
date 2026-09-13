import { Controller } from "@hotwired/stimulus"
import { t } from "../i18n.js"

// Connects to data-controller="intl-tel-input"
export default class extends Controller {
  static targets = ["input"]
  static values = { options: Object }

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
    // Defaults first; the definition-supplied `options` value (e.g.
    // { initialCountry: "gh", strictMode: false }) is spread last so it wins.
    // Optional locale passthrough: plutonium.js.libraries.intl_tel_input is
    // the intl-tel-input `i18n` option (an object of strings).
    const i18n = t("plutonium.js.libraries.intl_tel_input")
    return {
      ...(i18n && typeof i18n === "object" ? { i18n } : {}),
      strictMode: true,
      hiddenInput: () => ({ phone: this.inputTarget.attributes.name.value }),
      loadUtilsOnInit: "https://cdn.jsdelivr.net/npm/intl-tel-input@24.8.1/build/js/utils.js",
      ...this.optionsValue,
    }
  }
}

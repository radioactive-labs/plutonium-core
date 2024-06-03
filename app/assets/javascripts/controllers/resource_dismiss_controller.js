import { Controller } from "@hotwired/stimulus"
import { Dismiss } from 'flowbite';


// Connects to data-controller="resource-dismiss"
export default class extends Controller {
  static targets = ["trigger", "target"]

  static values = {
    after: Number,
  }

  connect() {
    console.log(`resource-dismiss connected: ${this.element}`)

    // https://flowbite.com/docs/components/alerts/#javascript-behaviour
    this.dismiss = new Dismiss(this.targetTarget, this.triggerTarget);

    console.log(this.hasAfterValue)
    console.log(this.afterValue)
    if (this.hasAfterValue && this.afterValue > 0) {
      this.autoDismissTimeout = setTimeout(() => {
        this.hide()
        this.autoDismissTimeout = null
      }, this.afterValue);
    }
  }

  disconnect() {
    if (this.autoDismissTimeout) clearTimeout(this.autoDismissTimeout)

    this.dismiss = null
    this.autoDismissTimeout = null
  }

  hide() {
    this.dismiss.hide()
  }
}

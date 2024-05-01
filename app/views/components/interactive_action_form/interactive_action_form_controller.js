import { Controller } from "@hotwired/stimulus"
import debounce from "lodash.debounce";

// Connects to data-controller="interactive-action-form"
export default class extends Controller {
  connect() {
    console.log(`interactive-action-form connected: ${this.element}`)
  }

  submit() {
    this.element.requestSubmit()
  }
}

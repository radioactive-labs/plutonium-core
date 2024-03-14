import { Controller } from "@hotwired/stimulus"
import debounce from "lodash.debounce";

// Connects to data-controller="form"
export default class extends Controller {
  connect() {
    console.log(`form connected: ${this.element}`)
  }

  submit() {
    this.element.requestSubmit()
  }
}

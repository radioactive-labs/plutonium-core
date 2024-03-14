import { Controller } from "@hotwired/stimulus"
import debounce from "lodash.debounce";

// Connects to data-controller="form"
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}

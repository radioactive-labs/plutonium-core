import { Controller } from "@hotwired/stimulus"
import debounce from "lodash.debounce";

// Connects to data-controller="form"
export default class extends Controller {
  static targets = ["focus"]

  connect() {
    // this.submit = debounce(this.submit, 1000).bind(this)

    this._maybeFocusTarget()
  }

  submit() {
    this.element.requestSubmit()
  }

  _maybeFocusTarget() {
    if (!this.focusTarget) return;

    let value = this.focusTarget.value
    if (value) {
      // move the cursor to the end of the input
      this.focusTarget.value = ""
      this.focusTarget.value = value
    }
    this.focusTarget.focus()
  }
}

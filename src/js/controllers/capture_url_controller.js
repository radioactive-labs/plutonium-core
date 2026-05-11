import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="capture-url"
// Sets the controller's own element's `value` to window.location.href
// on connect — capturing URL fragments (#tab-id) that the server never
// sees over HTTP. Apply directly to any input/button whose value should
// reflect the full client-side URL.
export default class extends Controller {
  connect() {
    if ("value" in this.element) {
      this.element.value = window.location.href
    }
  }
}

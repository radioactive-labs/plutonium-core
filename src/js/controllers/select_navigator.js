import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="select-navigator"
export default class extends Controller {
  static targets = ["select"]

  navigate(_) {
    const url = this.selectTarget.value
    const anchor = document.createElement('a')
    anchor.href = url

    this.element.appendChild(anchor)
    anchor.click()
    anchor.remove()
  }
}

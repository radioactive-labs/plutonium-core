import { Controller } from "@hotwired/stimulus"
import { Collapse } from 'flowbite';


// Connects to data-controller="resource-collapse"
export default class extends Controller {
  static targets = ["trigger", "menu"]

  connect() {
    console.log(`resource-collapse connected: ${this.element}`)

    this.collapse = new Collapse(this.menuTarget, this.triggerTarget);
  }

  disconnect() {
    this.collapse = null
  }

  toggle() {
    this.collapse.toggle()
  }

  show() {
    this.collapse.show()
  }

  hide() {
    this.collapse.hide()
  }
}

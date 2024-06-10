import { Controller } from "@hotwired/stimulus"
import { Dropdown } from 'flowbite';


// Connects to data-controller="resource-drop-down"
export default class extends Controller {
  static targets = ["trigger", "menu"]

  connect() {
    console.log(`resource-drop-down connected: ${this.element}`)

    // https://flowbite.com/docs/components/dropdowns/#javascript-behaviour
    this.dropdown = new Dropdown(this.menuTarget, this.triggerTarget);
  }

  disconnect() {
    this.dropdown = null
  }

  toggle() {
    this.dropdown.toggle()
  }

  show() {
    this.dropdown.show()
  }

  hide() {
    this.dropdown.hide()
  }
}

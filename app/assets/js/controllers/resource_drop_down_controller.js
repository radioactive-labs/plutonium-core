import { Controller } from "@hotwired/stimulus"
import { Dropdown } from 'flowbite';


// Connects to data-resource-drop-down-target="trigger"
export default class extends Controller {
  static targets = ["trigger", "menu"]

  connect() {
    console.log(`resource-drop-down connected: ${this.element}`)

    // https://flowbite.com/docs/components/dropdowns/#javascript-behaviour
    this.dropdown = new Dropdown(this.menuTarget, this.triggerTarget);
  }

  disconnect() {
    console.log(`resource-drop-down disconnected: ${this.element}`)
    this.dropdown = null
  }

  toggle() {
    this.dropdown.toggle()
  }

  show() {
    this.dropdown.show()
  }

  hide() {
    this.dropdown.show()
  }
}

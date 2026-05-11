import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-panel"
//
// Hosts the toolbar's filter slideover. The trigger lives in the toolbar
// strip; the panel + backdrop are rendered as siblings inside the same
// controller scope. `open` is mirrored on both targets via the `data-open`
// attribute, which CSS uses to drive the slide / fade transitions.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this._onKeydown = this._onKeydown.bind(this)
  }

  disconnect() {
    if (this.isOpen) {
      document.removeEventListener("keydown", this._onKeydown)
      this._unlockBodyScroll()
    }
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    if (this.hasPanelTarget) {
      this.panelTarget.setAttribute("data-open", "")
      this.panelTarget.setAttribute("aria-hidden", "false")
    }
    if (this.hasBackdropTarget) this.backdropTarget.setAttribute("data-open", "")
    this._lockBodyScroll()
    document.addEventListener("keydown", this._onKeydown)
  }

  close() {
    if (this.hasPanelTarget) {
      this.panelTarget.removeAttribute("data-open")
      this.panelTarget.setAttribute("aria-hidden", "true")
    }
    if (this.hasBackdropTarget) this.backdropTarget.removeAttribute("data-open")
    this._unlockBodyScroll()
    document.removeEventListener("keydown", this._onKeydown)
  }

  // Mirrors remote-modal's approach: stash the body's current overflow
  // and restore it on close. Avoids stomping a value another component
  // (e.g. an open dialog) may have set.
  _lockBodyScroll() {
    if (this._previousBodyOverflow != null) return
    this._previousBodyOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
  }

  _unlockBodyScroll() {
    if (this._previousBodyOverflow == null) return
    document.body.style.overflow = this._previousBodyOverflow
    this._previousBodyOverflow = null
  }

  // Reset every input under this controller's scope, then submit so the
  // table reflects the cleared filters immediately.
  clear() {
    this.element.querySelectorAll("input, select, textarea").forEach(input => {
      if (input.type === "checkbox" || input.type === "radio") {
        input.checked = false
      } else if (input.tagName === "SELECT") {
        input.selectedIndex = 0
      } else if (input.type === "hidden") {
        if (input.dataset.controller === "flatpickr") input.value = ""
      } else {
        input.value = ""
      }
    })

    this.element.querySelectorAll('[data-controller="flatpickr"]').forEach(input => {
      const controller = this.application.getControllerForElementAndIdentifier(input, "flatpickr")
      if (controller?.picker) controller.picker.clear()
    })

    const form = this.element.querySelector("form")
    if (form) form.requestSubmit()
  }

  get isOpen() {
    return this.hasPanelTarget && this.panelTarget.hasAttribute("data-open")
  }

  _onKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}

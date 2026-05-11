import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table-column-menu"
// Toggles the column ⋯ menu panel; closes on outside click and Escape.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this._onDocClick = this._onDocClick.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasPanelTarget) {
      const isNowVisible = !this.panelTarget.classList.toggle("hidden")
      if (isNowVisible) {
        document.addEventListener("click", this._onDocClick)
        this._onKey = (e) => { if (e.key === "Escape") this._close() }
        document.addEventListener("keydown", this._onKey)
      } else {
        this._unbind()
      }
    }
  }

  _close() {
    if (this.hasPanelTarget) this.panelTarget.classList.add("hidden")
    this._unbind()
  }

  _unbind() {
    document.removeEventListener("click", this._onDocClick)
    if (this._onKey) {
      document.removeEventListener("keydown", this._onKey)
      this._onKey = null
    }
  }

  _onDocClick(event) {
    if (!this.element.contains(event.target)) this._close()
  }
}

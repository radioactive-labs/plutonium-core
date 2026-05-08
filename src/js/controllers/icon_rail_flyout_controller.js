import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="icon-rail-flyout"
// Manages a flyout panel anchored to a trigger element.
// - Hover or focus the wrapper → open
// - Mouse leave (with delay) or blur → close
// - Esc → close immediately
// - Click trigger → toggle (touch-friendly)
export default class extends Controller {
  static targets = ["trigger", "panel"]
  static values = {
    closeDelay: { type: Number, default: 150 }
  }

  connect() {
    this._closeTimer = null
    this._open = false
  }

  open() {
    if (this._closeTimer) {
      clearTimeout(this._closeTimer)
      this._closeTimer = null
    }
    if (this._open) return
    this._open = true
    this.element.dataset.flyoutOpen = "true"
    this._position()
  }

  scheduleClose() {
    if (this._closeTimer) clearTimeout(this._closeTimer)
    this._closeTimer = setTimeout(() => this.close(), this.closeDelayValue)
  }

  close() {
    this._open = false
    delete this.element.dataset.flyoutOpen
  }

  toggle(event) {
    event.preventDefault()
    this._open ? this.close() : this.open()
  }

  closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  _position() {
    if (!this.hasPanelTarget || !this.hasTriggerTarget) return
    const triggerRect = this.triggerTarget.getBoundingClientRect()
    const panel = this.panelTarget
    panel.style.position = "fixed"
    panel.style.left = `${triggerRect.right + 4}px`
    panel.style.top = `${triggerRect.top}px`

    // After the panel is laid out, check viewport overflow and shift if needed.
    requestAnimationFrame(() => {
      const panelRect = panel.getBoundingClientRect()
      const viewportH = window.innerHeight
      if (panelRect.bottom > viewportH - 8) {
        const overflow = panelRect.bottom - (viewportH - 8)
        panel.style.top = `${parseFloat(panel.style.top) - overflow}px`
      }
    })
  }
}

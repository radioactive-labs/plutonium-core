import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="icon-rail-flyout"
// Manages a flyout panel anchored to a trigger element.
// - Hover or focus the wrapper → open
// - Mouse leave (with delay) or blur → close
// - Esc → close immediately
// - Click trigger → toggle (touch-friendly)
//
// On open, the panel is portaled to <body> so it escapes any ancestor
// transform / overflow:hidden (the rail aside has both). On close,
// the panel returns to its original parent.
//
// IMPORTANT: once portaled, the panel is OUTSIDE the controller's
// element scope, so this.panelTarget stops resolving. We capture the
// node into _panel before moving it.
export default class extends Controller {
  static targets = ["trigger", "panel"]
  static values = {
    closeDelay: { type: Number, default: 150 }
  }

  connect() {
    this._closeTimer = null
    this._open = false
    this._panel = null
    this._panelHome = null
    this._onPanelEnter = () => {
      if (this._closeTimer) {
        clearTimeout(this._closeTimer)
        this._closeTimer = null
      }
    }
    this._onPanelLeave = () => this.scheduleClose()
  }

  disconnect() {
    this._returnPanel()
  }

  open() {
    if (this._closeTimer) {
      clearTimeout(this._closeTimer)
      this._closeTimer = null
    }
    if (this._open) return
    if (!this._panel && !this.hasPanelTarget) return
    this._open = true
    this.element.dataset.flyoutOpen = "true"
    this._portalPanel()
    this._position()
  }

  scheduleClose() {
    if (this._closeTimer) clearTimeout(this._closeTimer)
    this._closeTimer = setTimeout(() => this.close(), this.closeDelayValue)
  }

  close() {
    if (!this._open) return
    this._open = false
    delete this.element.dataset.flyoutOpen
    this._returnPanel()
  }

  toggle(event) {
    event.preventDefault()
    this._open ? this.close() : this.open()
  }

  closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  _portalPanel() {
    if (this._panel) return
    // Capture the panel BEFORE moving it — once it leaves the
    // controller element, this.panelTarget no longer resolves.
    const panel = this.panelTarget
    if (!panel) return
    this._panel = panel
    this._panelHome = panel.parentElement
    panel.addEventListener("mouseenter", this._onPanelEnter)
    panel.addEventListener("mouseleave", this._onPanelLeave)
    document.body.appendChild(panel)
    panel.style.display = "block"
  }

  _returnPanel() {
    if (!this._panel) return
    const panel = this._panel
    panel.removeEventListener("mouseenter", this._onPanelEnter)
    panel.removeEventListener("mouseleave", this._onPanelLeave)
    panel.style.position = ""
    panel.style.left = ""
    panel.style.top = ""
    panel.style.display = ""
    // If the original parent has been morphed away, the panel would
    // orphan in <body>. Drop it instead of re-attaching to a detached
    // home node.
    if (this._panelHome && document.contains(this._panelHome)) {
      this._panelHome.appendChild(panel)
    } else {
      panel.remove()
    }
    this._panel = null
    this._panelHome = null
  }

  _position() {
    if (!this._panel || !this.hasTriggerTarget) return
    const panel = this._panel
    const triggerRect = this.triggerTarget.getBoundingClientRect()
    panel.style.position = "fixed"
    panel.style.left = `${triggerRect.right + 4}px`
    panel.style.top = `${triggerRect.top}px`

    // Shift up if the panel would overflow the viewport bottom.
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

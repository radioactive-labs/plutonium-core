import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="autosubmit"
// Submits the closest <form> after the user stops typing for `delay` ms
// (default 300). Use on inputs where the user expects "as you type"
// behavior (e.g. the toolbar search input).
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this._timer = null
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer)
  }

  submit() {
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(() => {
      this.element.closest("form")?.requestSubmit()
    }, this.delayValue)
  }
}

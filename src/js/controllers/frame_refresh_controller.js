import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="frame-refresh"
//
// Reloads a `<turbo-frame src>` every `interval` seconds while the tab is
// visible, so a dashboard card declared with `refresh:` keeps itself current
// without a page reload. Pauses when the document is hidden and resumes with
// an immediate reload when it becomes visible again after a missed tick.
export default class extends Controller {
  static values = { interval: Number }

  connect() {
    this.tick = this.tick.bind(this)
    this.onVisibility = this.onVisibility.bind(this)
    document.addEventListener("visibilitychange", this.onVisibility)
    this.#start()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.#stop()
  }

  intervalValueChanged() {
    this.#stop()
    this.#start()
  }

  tick() {
    if (document.hidden) {
      this.missed = true
      return
    }
    this.reload()
  }

  reload() {
    this.missed = false
    if (typeof this.element.reload === "function" && this.element.getAttribute("src")) {
      this.element.reload()
    }
  }

  onVisibility() {
    if (!document.hidden && this.missed) this.reload()
  }

  #start() {
    if (!(this.intervalValue > 0)) return
    this.timer = setInterval(this.tick, this.intervalValue * 1000)
  }

  #stop() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}

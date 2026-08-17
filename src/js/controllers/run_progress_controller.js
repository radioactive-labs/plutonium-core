import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="run-progress"
//
// Re-fetches the enclosing turbo-frame on an interval so an interaction run's
// progress page updates itself. Polling rather than ActionCable: it needs no
// cable server, so it works on every deployment.
//
// The element carrying this controller lives INSIDE the frame it reloads, and
// the server only emits it while the run is in progress. So each refresh
// disconnects this instance and connects a new one — until the run finishes,
// when the replacement markup carries no controller at all and the polling
// stops. That is the whole stop condition: nothing here has to know what
// "finished" means, and no timer outlives the work it was watching.
export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 2000 },
  }

  connect() {
    this.schedule()
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
  }

  schedule() {
    this.timer = setTimeout(() => this.refresh(), this.intervalValue)
  }

  refresh() {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    // The frame is rendered WITHOUT a src (it arrives as part of the full page,
    // so an eager src would cost a second request on every page load). Setting
    // it is what triggers the first fetch; after that reload() re-uses it.
    if (frame.src) {
      frame.reload()
    } else {
      frame.src = this.urlValue
    }
  }
}

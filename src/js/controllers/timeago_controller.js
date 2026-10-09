import { Controller } from "@hotwired/stimulus"

// Renders a <time> as relative text ("3 days ago", "in 5 minutes") in the
// page's locale and keeps it current. The server-rendered absolute date stays
// in the element's title, so hovering still shows the exact time.
const UNITS = [
  ["year", 60 * 60 * 24 * 365],
  ["month", 60 * 60 * 24 * 30],
  ["week", 60 * 60 * 24 * 7],
  ["day", 60 * 60 * 24],
  ["hour", 60 * 60],
  ["minute", 60],
  ["second", 1],
]

export default class extends Controller {
  static values = {
    datetime: String,
    refreshInterval: { type: Number, default: 60000 },
  }

  connect() {
    this.formatter = new Intl.RelativeTimeFormat(document.documentElement.lang || undefined, { numeric: "auto" })
    this.render()
    this.timer = setInterval(() => this.render(), this.refreshIntervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    const date = new Date(this.datetimeValue)
    if (isNaN(date)) return

    const seconds = Math.round((date - Date.now()) / 1000)
    const [unit, size] = UNITS.find(([, size]) => Math.abs(seconds) >= size) || UNITS[UNITS.length - 1]
    this.element.textContent = this.formatter.format(Math.round(seconds / size), unit)
  }
}

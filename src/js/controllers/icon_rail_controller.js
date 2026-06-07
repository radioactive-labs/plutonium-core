import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="icon-rail"
// Manages the collapsed ↔ pinned-expanded state of the IconRail sidebar.
// Pinned state is persisted in localStorage so it survives page reloads.
export default class extends Controller {
  static values = {
    storageKey: { type: String, default: "pu_rail_pinned" }
  }

  connect() {
    // Pinned is the default; only an explicit "false" collapses the rail.
    const pinned = localStorage.getItem(this.storageKeyValue) !== "false"
    document.body.classList.toggle("pu-rail-pinned", pinned)
  }

  togglePin() {
    const pinned = document.body.classList.toggle("pu-rail-pinned")
    localStorage.setItem(this.storageKeyValue, pinned)
  }
}

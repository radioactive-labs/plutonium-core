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
    document.documentElement.classList.toggle("pu-rail-pinned", pinned)
  }

  disconnect() {
    // Guard: if another icon-rail is already in the DOM (Turbo swapped to a
    // page that also has a rail), leave the class alone — the new controller's
    // connect() will assert the correct value immediately after.
    if (!document.querySelector('[data-controller~="icon-rail"]')) {
      document.documentElement.classList.remove("pu-rail-pinned")
    }
  }

  togglePin() {
    const pinned = document.documentElement.classList.toggle("pu-rail-pinned")
    localStorage.setItem(this.storageKeyValue, pinned)
  }
}

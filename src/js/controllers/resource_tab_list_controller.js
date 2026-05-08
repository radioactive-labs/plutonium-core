import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resource-tab-list"
//
// URL hash sync:
// - On connect, if location.hash matches a tab identifier, that tab is
//   selected (overrides defaultTabValue). Falls back to defaultTabValue
//   or the first tab.
// - On user click, the URL hash is updated via history.replaceState
//   (no scroll, no back-button entry).
// - On hashchange (back/forward, manual hash edit), the matching tab
//   is re-selected.
export default class extends Controller {
  static targets = ["btn", "tab"]
  static values = {
    defaultTab: String,
    activeClasses: String,
    inActiveClasses: String
  }

  connect() {
    this.activeClasses = this.hasActiveClassesValue ? this.activeClassesValue.split(" ") : []
    this.inActiveClasses = this.hasInActiveClassesValue ? this.inActiveClassesValue.split(" ") : []

    const fromHash = this.#buttonIdFromHash()
    const initialId = fromHash || this.defaultTabValue || this.btnTargets[0]?.id
    this.#selectInternal(initialId, { skipFocus: true, skipHashUpdate: true })

    this._syncFromHash = this._syncFromHash.bind(this)
    // hashchange covers manual hash edits and back/forward.
    window.addEventListener("hashchange", this._syncFromHash)
    // turbo:load covers Turbo navigations (including morph) where the URL
    // changes via pushState — which doesn't fire hashchange. Without this,
    // a second submit landing via morph leaves the previously-active tab
    // selected even though the URL hash points elsewhere.
    document.addEventListener("turbo:load", this._syncFromHash)
  }

  disconnect() {
    if (this._syncFromHash) {
      window.removeEventListener("hashchange", this._syncFromHash)
      document.removeEventListener("turbo:load", this._syncFromHash)
    }
  }

  _syncFromHash() {
    const id = this.#buttonIdFromHash()
    if (id) this.#selectInternal(id, { skipFocus: true, skipHashUpdate: true })
  }

  select(event) {
    this.#selectInternal(event.currentTarget.id)
  }

  #selectInternal(id, options = {}) {
    const selectedBtn = this.btnTargets.find(element => element.id === id)
    if (!selectedBtn) {
      console.error(`Tab Button with id "${id}" not found`)
      return
    }

    const selectedTab = this.tabTargets.find(element => element.id === selectedBtn.dataset.target)
    if (!selectedTab) {
      console.error(`Tab Panel with id "${selectedBtn.dataset.target}" not found`)
      return
    }

    // Update tab visibility and ARIA states
    this.tabTargets.forEach(tab => {
      tab.hidden = true
      tab.setAttribute('aria-hidden', 'true')
    })

    // Update button states and classes
    this.btnTargets.forEach(btn => {
      btn.setAttribute('aria-selected', 'false')
      btn.setAttribute('tabindex', '-1')
      btn.classList.remove(...this.activeClasses)
      btn.classList.add(...this.inActiveClasses)
    })

    // Activate selected tab and button
    selectedBtn.setAttribute('aria-selected', 'true')
    selectedBtn.setAttribute('tabindex', '0')
    selectedBtn.classList.remove(...this.inActiveClasses)
    selectedBtn.classList.add(...this.activeClasses)

    selectedTab.hidden = false
    selectedTab.setAttribute('aria-hidden', 'false')

    // Sync URL hash so the tab is shareable / restorable on reload.
    if (!options.skipHashUpdate) this.#updateHash(id)

    // Focus management
    if (!options.skipFocus && selectedBtn !== document.activeElement) {
      selectedBtn.focus()
    }
  }

  // Button ids follow `${identifier}-tab`. The URL hash carries just
  // the identifier (e.g., #details, #orders).
  #buttonIdFromHash() {
    const hash = window.location.hash.replace(/^#/, "")
    if (!hash) return null
    const candidateId = `${hash}-tab`
    const exists = this.btnTargets.some(btn => btn.id === candidateId)
    return exists ? candidateId : null
  }

  #updateHash(buttonId) {
    const identifier = buttonId.replace(/-tab$/, "")
    const newHash = `#${identifier}`
    if (window.location.hash !== newHash) {
      history.replaceState(null, "", newHash)
    }
  }
}

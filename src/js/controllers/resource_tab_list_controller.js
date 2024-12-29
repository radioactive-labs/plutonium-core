import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resource-tab-list"
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

    this.#selectInternal(this.defaultTabValue || this.btnTargets[0].id)
  }

  select(event) {
    this.#selectInternal(event.currentTarget.id)
  }

  #selectInternal(id) {
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

    // Focus management
    if (selectedBtn !== document.activeElement) {
      selectedBtn.focus()
    }
  }
}

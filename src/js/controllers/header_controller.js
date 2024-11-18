import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["open", "close"]
  static outlets = ["sidebar"]
  static values = {
    placement: { type: String, default: "left" },
    bodyScrolling: { type: Boolean, default: false },
    backdrop: { type: Boolean, default: true },
    edge: { type: Boolean, default: false },
    edgeOffset: { type: String, default: "bottom-[60px]" }
  }
  static classes = {
    backdrop: "bg-gray-900/50 dark:bg-gray-900/80 fixed inset-0 z-30"
  }

  initialize() {
    this.visible = false
    this.handleEscapeKey = this.handleEscapeKey.bind(this)
  }

  connect() {
    document.addEventListener("keydown", this.handleEscapeKey)
  }

  sidebarOutletConnected() {
    this.#setupDrawer(this.sidebarOutlet.element)
  }

  disconnect() {
    this.#removeBackdrop()
    document.removeEventListener("keydown", this.handleEscapeKey)
    if (!this.bodyScrollingValue) {
      document.body.classList.remove("overflow-hidden")
    }
  }

  #setupDrawer(drawerElement) {
    drawerElement.setAttribute("aria-hidden", "true")
    drawerElement.classList.add("transition-transform")

    // Add base placement classes
    this.#getPlacementClasses(this.placementValue).base.forEach(className => {
      drawerElement.classList.add(className)
    })
  }

  toggleDrawer() {
    this.visible ? this.hideDrawer() : this.showDrawer()
  }

  showDrawer() {
    if (this.edgeValue) {
      this.#toggleEdgePlacementClasses(`${this.placementValue}-edge`, true)
    } else {
      this.#togglePlacementClasses(this.placementValue, true)
    }

    // Toggle visibility and ARIA attributes of icons
    this.openTarget.classList.add("hidden")
    this.openTarget.setAttribute("aria-hidden", "true")

    this.closeTarget.classList.remove("hidden")
    this.closeTarget.setAttribute("aria-hidden", "false")

    // Rest of the method stays same...
    this.sidebarOutlet.element.setAttribute("aria-modal", "true")
    this.sidebarOutlet.element.setAttribute("role", "dialog")
    this.sidebarOutlet.element.removeAttribute("aria-hidden")

    if (!this.bodyScrollingValue) {
      document.body.classList.add("overflow-hidden")
    }

    if (this.backdropValue) {
      this.#createBackdrop()
    }

    this.visible = true
    this.dispatch("show")
  }

  hideDrawer() {
    if (this.edgeValue) {
      this.#toggleEdgePlacementClasses(`${this.placementValue}-edge`, false)
    } else {
      this.#togglePlacementClasses(this.placementValue, false)
    }

    // Toggle visibility and ARIA attributes of icons
    this.openTarget.classList.remove("hidden")
    this.openTarget.setAttribute("aria-hidden", "false")

    this.closeTarget.classList.add("hidden")
    this.closeTarget.setAttribute("aria-hidden", "true")

    // Rest of the method stays same...
    this.sidebarOutlet.element.setAttribute("aria-hidden", "true")
    this.sidebarOutlet.element.removeAttribute("aria-modal")
    this.sidebarOutlet.element.removeAttribute("role")

    if (!this.bodyScrollingValue) {
      document.body.classList.remove("overflow-hidden")
    }

    if (this.backdropValue) {
      this.#removeBackdrop()
    }

    this.visible = false
    this.dispatch("hide")
  }

  handleEscapeKey(event) {
    if (event.key === "Escape" && this.visible) {
      this.hideDrawer()
    }
  }

  #createBackdrop() {
    if (!this.visible) {
      const backdrop = document.createElement("div")
      backdrop.setAttribute("data-drawer-backdrop", "")
      backdrop.classList.add(...this.constructor.classes.backdrop.split(" "))
      backdrop.addEventListener("click", () => this.hideDrawer())
      document.body.appendChild(backdrop)
    }
  }

  #removeBackdrop() {
    const backdrop = document.querySelector("[data-drawer-backdrop]")
    if (backdrop) {
      backdrop.remove()
    }
  }

  #getPlacementClasses(placement) {
    const placements = {
      top: {
        base: ["top-0", "left-0", "right-0"],
        active: ["transform-none"],
        inactive: ["-translate-y-full"]
      },
      right: {
        base: ["right-0", "top-0"],
        active: ["transform-none"],
        inactive: ["translate-x-full"]
      },
      bottom: {
        base: ["bottom-0", "left-0", "right-0"],
        active: ["transform-none"],
        inactive: ["translate-y-full"]
      },
      left: {
        base: ["left-0", "top-0"],
        active: ["transform-none"],
        inactive: ["-translate-x-full"]
      },
      "bottom-edge": {
        base: ["left-0", "top-0"],
        active: ["transform-none"],
        inactive: ["translate-y-full", this.edgeOffsetValue]
      }
    }

    return placements[placement] || placements.left
  }

  #togglePlacementClasses(placement, show) {
    const classes = this.#getPlacementClasses(placement)

    if (show) {
      classes.active.forEach(c => this.sidebarOutlet.element.classList.add(c))
      classes.inactive.forEach(c => this.sidebarOutlet.element.classList.remove(c))
    } else {
      classes.active.forEach(c => this.sidebarOutlet.element.classList.remove(c))
      classes.inactive.forEach(c => this.sidebarOutlet.element.classList.add(c))
    }
  }

  #toggleEdgePlacementClasses(placement, show) {
    this.#togglePlacementClasses(placement, show)
  }
}

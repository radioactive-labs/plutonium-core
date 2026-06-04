import { Controller } from "@hotwired/stimulus"
import { createPopper } from '@popperjs/core'

// Connects to data-controller="resource-drop-down"
export default class extends Controller {
  static targets = ["trigger", "menu"]
  static values = {
    placement: { type: String, default: 'bottom' }
  }

  connect() {
    this.visible = false
    this.initialized = false

    // Default options matching Flowbite's defaults
    this.options = {
      placement: this.placementValue,
      triggerType: 'click',
      offsetSkidding: 0,
      offsetDistance: 10,
      delay: 300,
      ignoreClickOutsideClass: false
    }

    this.init()
  }

  init() {
    if (this.triggerTarget && this.menuTarget && !this.initialized) {
      // Capture a direct reference to the menu node. While open we teleport
      // it to <body> (see show/hide), which moves it out of this controller's
      // scope — so `this.menuTarget` would throw. Remember its home so we can
      // put it back on hide/disconnect.
      this.menu = this.menuTarget
      this.menuHome = { parent: this.menu.parentNode, next: this.menu.nextSibling }

      // Initialize popper instance
      // Use 'fixed' strategy to escape overflow containers (e.g., table rows)
      this.popperInstance = createPopper(this.triggerTarget, this.menu, {
        strategy: 'fixed',
        placement: this.options.placement,
        modifiers: [
          {
            name: 'offset',
            options: {
              offset: [this.options.offsetSkidding, this.options.offsetDistance],
            },
          },
          {
            name: 'flip',
            options: {
              fallbackPlacements: ['bottom-end', 'bottom-start', 'top', 'top-end', 'top-start'],
              boundary: 'viewport',
            },
          },
          {
            name: 'preventOverflow',
            options: {
              boundary: 'viewport',
              altAxis: true,
              padding: 8,
            },
          },
        ],
      })

      this.setupEventListeners()
      this.initialized = true
    }
  }

  disconnect() {
    if (this.initialized) {
      // Remove click event listeners
      if (this.options.triggerType === 'click') {
        this.triggerTarget.removeEventListener('click', this.clickHandler)
      }

      // Remove hover event listeners
      if (this.options.triggerType === 'hover') {
        this.triggerTarget.removeEventListener('mouseenter', this.hoverShowTriggerHandler)
        this.menu.removeEventListener('mouseenter', this.hoverShowMenuHandler)
        this.triggerTarget.removeEventListener('mouseleave', this.hoverHideHandler)
        this.menu.removeEventListener('mouseleave', this.hoverHideHandler)
      }

      // Remove click outside listener
      this.removeClickOutsideListener()

      // Put the menu back where it belongs before we tear down, so a teleported
      // menu isn't orphaned in <body> after the controller goes away. If its
      // home is gone (e.g. turbo swapped the surrounding content), drop it.
      this.restoreMenu()
      if (this.menu.parentNode === document.body) {
        this.menu.remove()
      }

      // Destroy popper instance
      this.popperInstance.destroy()
      this.initialized = false
    }
  }

  // Move the menu to <body> so no ancestor's overflow + containing-block
  // (transform/filter/will-change) can clip it. popper's 'fixed' strategy
  // positions relative to the viewport, but painting is still clipped by a
  // transformed, overflow-hidden ancestor (e.g. grid cards) — teleporting
  // sidesteps that entirely.
  teleportMenu() {
    if (this.menu.parentNode !== document.body) {
      document.body.appendChild(this.menu)
    }
  }

  restoreMenu() {
    const home = this.menuHome
    if (home && home.parent && home.parent.isConnected && this.menu.parentNode !== home.parent) {
      home.parent.insertBefore(this.menu, home.next)
    }
  }

  setupEventListeners() {
    // Bind handlers to preserve context
    this.clickHandler = this.toggle.bind(this)
    this.hoverShowTriggerHandler = (ev) => {
      if (ev.type === 'click') {
        this.toggle()
      } else {
        setTimeout(() => {
          this.show()
        }, this.options.delay)
      }
    }
    this.hoverShowMenuHandler = () => {
      this.show()
    }
    this.hoverHideHandler = () => {
      setTimeout(() => {
        if (!this.menu.matches(':hover')) {
          this.hide()
        }
      }, this.options.delay)
    }

    // Set up click or hover events based on trigger type
    if (this.options.triggerType === 'click') {
      this.triggerTarget.addEventListener('click', this.clickHandler)
    } else if (this.options.triggerType === 'hover') {
      this.triggerTarget.addEventListener('mouseenter', this.hoverShowTriggerHandler)
      this.menu.addEventListener('mouseenter', this.hoverShowMenuHandler)
      this.triggerTarget.addEventListener('mouseleave', this.hoverHideHandler)
      this.menu.addEventListener('mouseleave', this.hoverHideHandler)
    }
  }

  setupClickOutsideListener() {
    this.clickOutsideHandler = (ev) => {
      const clickedEl = ev.target
      const ignoreClickOutsideClass = this.options.ignoreClickOutsideClass

      let isIgnored = false
      if (ignoreClickOutsideClass) {
        const ignoredEls = document.querySelectorAll(`.${ignoreClickOutsideClass}`)
        ignoredEls.forEach((el) => {
          if (el.contains(clickedEl)) {
            isIgnored = true
            return
          }
        })
      }

      // Ignore clicks on flatpickr calendars and other floating UI elements
      const isFloatingUI = clickedEl.closest('.flatpickr-calendar, .ss-main, .ss-content')

      if (
        clickedEl !== this.menu &&
        !this.menu.contains(clickedEl) &&
        !this.triggerTarget.contains(clickedEl) &&
        !isIgnored &&
        !isFloatingUI &&
        this.visible
      ) {
        this.hide()
      }
    }

    document.body.addEventListener('click', this.clickOutsideHandler, true)
  }

  removeClickOutsideListener() {
    if (this.clickOutsideHandler) {
      document.body.removeEventListener('click', this.clickOutsideHandler, true)
    }
  }

  toggle() {
    if (this.visible) {
      this.hide()
    } else {
      this.show()
    }
  }

  show() {
    this.teleportMenu()
    this.menu.classList.remove('hidden')
    this.menu.classList.add('block')
    this.menu.removeAttribute('aria-hidden')

    // Enable popper event listeners
    this.popperInstance.setOptions((options) => ({
      ...options,
      modifiers: [
        ...options.modifiers,
        { name: 'eventListeners', enabled: true },
      ],
    }))

    this.setupClickOutsideListener()
    this.popperInstance.update()
    this.visible = true
  }

  hide() {
    this.menu.classList.remove('block')
    this.menu.classList.add('hidden')
    this.menu.setAttribute('aria-hidden', 'true')

    // Disable popper event listeners
    this.popperInstance.setOptions((options) => ({
      ...options,
      modifiers: [
        ...options.modifiers,
        { name: 'eventListeners', enabled: false },
      ],
    }))

    this.removeClickOutsideListener()
    this.restoreMenu()
    this.visible = false
  }
}

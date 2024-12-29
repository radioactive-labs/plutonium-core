import { Controller } from "@hotwired/stimulus"
import { createPopper } from '@popperjs/core'

// Connects to data-controller="resource-drop-down"
export default class extends Controller {
  static targets = ["trigger", "menu"]

  connect() {
    this.visible = false
    this.initialized = false

    // Default options matching Flowbite's defaults
    this.options = {
      placement: 'bottom',
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
      // Initialize popper instance
      this.popperInstance = createPopper(this.triggerTarget, this.menuTarget, {
        placement: this.options.placement,
        modifiers: [
          {
            name: 'offset',
            options: {
              offset: [this.options.offsetSkidding, this.options.offsetDistance],
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
        this.menuTarget.removeEventListener('mouseenter', this.hoverShowMenuHandler)
        this.triggerTarget.removeEventListener('mouseleave', this.hoverHideHandler)
        this.menuTarget.removeEventListener('mouseleave', this.hoverHideHandler)
      }

      // Remove click outside listener
      this.removeClickOutsideListener()

      // Destroy popper instance
      this.popperInstance.destroy()
      this.initialized = false
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
        if (!this.menuTarget.matches(':hover')) {
          this.hide()
        }
      }, this.options.delay)
    }

    // Set up click or hover events based on trigger type
    if (this.options.triggerType === 'click') {
      this.triggerTarget.addEventListener('click', this.clickHandler)
    } else if (this.options.triggerType === 'hover') {
      this.triggerTarget.addEventListener('mouseenter', this.hoverShowTriggerHandler)
      this.menuTarget.addEventListener('mouseenter', this.hoverShowMenuHandler)
      this.triggerTarget.addEventListener('mouseleave', this.hoverHideHandler)
      this.menuTarget.addEventListener('mouseleave', this.hoverHideHandler)
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

      if (
        clickedEl !== this.menuTarget &&
        !this.menuTarget.contains(clickedEl) &&
        !this.triggerTarget.contains(clickedEl) &&
        !isIgnored &&
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
    this.menuTarget.classList.remove('hidden')
    this.menuTarget.classList.add('block')
    this.menuTarget.removeAttribute('aria-hidden')

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
    this.menuTarget.classList.remove('block')
    this.menuTarget.classList.add('hidden')
    this.menuTarget.setAttribute('aria-hidden', 'true')

    // Disable popper event listeners
    this.popperInstance.setOptions((options) => ({
      ...options,
      modifiers: [
        ...options.modifiers,
        { name: 'eventListeners', enabled: false },
      ],
    }))

    this.removeClickOutsideListener()
    this.visible = false
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    maxHeight: { type: Number, default: 0 } // 0 means use CSS max-height or 50vh
  }

  connect() {
    this.resize()
    this.element.addEventListener("input", this.resize)
    window.addEventListener("resize", this.resize)
  }

  disconnect() {
    this.element.removeEventListener("input", this.resize)
    window.removeEventListener("resize", this.resize)
  }

  resize = () => {
    const element = this.element
    const maxHeight = this.#getMaxHeight()

    // Reset to auto to get the natural scroll height
    element.style.height = "auto"
    element.style.overflow = "hidden"

    const scrollHeight = element.scrollHeight

    if (maxHeight > 0 && scrollHeight > maxHeight) {
      element.style.height = `${maxHeight}px`
      element.style.overflow = "auto"
    } else {
      element.style.height = `${scrollHeight}px`
    }
  }

  #getMaxHeight() {
    if (this.maxHeightValue > 0) {
      return this.maxHeightValue
    }

    // Check for CSS max-height
    const computedStyle = window.getComputedStyle(this.element)
    const cssMaxHeight = computedStyle.maxHeight

    if (cssMaxHeight && cssMaxHeight !== "none") {
      const parsed = parseFloat(cssMaxHeight)
      if (!isNaN(parsed) && parsed > 0) {
        return parsed
      }
    }

    // Default to 300px
    return 300
  }
}

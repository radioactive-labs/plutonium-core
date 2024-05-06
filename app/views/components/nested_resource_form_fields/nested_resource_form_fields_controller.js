import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nested-resource-form-fields"
// Copied from https://github.com/stimulus-components/stimulus-rails-nested-form/blob/master/src/index.ts
export default class extends Controller {
  static targets = ["target", "template", "addButton"]

  static values = {
    wrapperSelector: {
      type: String,
      default: ".nested-resource-form-fields",
    },
    limit: Number,
  }

  connect() {
    this.updateState()
  }

  add(e) {
    e.preventDefault()

    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    this.targetTarget.insertAdjacentHTML("beforebegin", content)

    const event = new CustomEvent("nested-resource-form-fields:add", { bubbles: true })
    this.element.dispatchEvent(event)

    this.updateState()
  }

  remove(e) {
    e.preventDefault()

    const wrapper = e.target.closest(this.wrapperSelectorValue)

    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove()
    } else {
      wrapper.style.display = "none"

      const input = wrapper.querySelector("input[name*='_destroy']")
      input.value = "1"
    }

    const event = new CustomEvent("nested-resource-form-fields:remove", { bubbles: true })
    this.element.dispatchEvent(event)

    this.updateState()
  }

  updateState() {
    if (!this.hasAddButtonTarget || this.limitValue == 0) return

    if (this.childCount >= this.limitValue)
      this.addButtonTarget.style.display = "none"
    else
      this.addButtonTarget.style.display = "initial"
  }

  get childCount() {
    return this.element.querySelectorAll(this.wrapperSelectorValue).length
  }
}

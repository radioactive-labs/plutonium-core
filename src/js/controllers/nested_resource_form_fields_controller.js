import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nested-resource-form-fields"
// Adapted from https://github.com/stimulus-components/stimulus-rails-nested-form
//
// Persisted rows soft-delete: the row collapses to a "Removed — Restore" bar,
// its `_destroy` flag flips to "1", and it drops out of the row count so the
// add button can come back. Restoring reverses all three. Unpersisted rows are
// removed from the DOM outright — there is nothing to restore server-side.
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

    this.dispatch("add")
    this.updateState()
  }

  remove(e) {
    e.preventDefault()

    const wrapper = e.target.closest(this.wrapperSelectorValue)
    if (wrapper.dataset.newRecord !== undefined) {
      wrapper.remove()
    } else {
      this.toggleRemoved(wrapper, true)
    }

    this.dispatch("remove")
    this.updateState()
  }

  restore(e) {
    e.preventDefault()

    const wrapper = e.target.closest(this.wrapperSelectorValue)
    this.toggleRemoved(wrapper, false)

    this.dispatch("restore")
    this.updateState()
  }

  // Collapse a persisted row to its "Removed" bar (or expand it back), keeping
  // the `_destroy` flag and the removed-state marker in sync.
  toggleRemoved(wrapper, removed) {
    wrapper.toggleAttribute("data-removed", removed)

    const content = wrapper.querySelector(":scope > [data-nested-content]")
    const removedBar = wrapper.querySelector(":scope > [data-nested-removed]")
    if (content) content.hidden = removed
    if (removedBar) removedBar.hidden = !removed

    const destroyInput = wrapper.querySelector("input[name*='_destroy']")
    if (destroyInput) destroyInput.value = removed ? "1" : "0"
  }

  updateState() {
    if (!this.hasAddButtonTarget || this.limitValue == 0) return

    if (this.childCount >= this.limitValue)
      this.addButtonTarget.style.display = "none"
    else
      this.addButtonTarget.style.display = "initial"
  }

  // Removed rows keep their wrapper (so they can be restored) but are excluded
  // from the count so the limit reflects rows that will actually be saved.
  get childCount() {
    return this.element.querySelectorAll(`${this.wrapperSelectorValue}:not([data-removed])`).length
  }
}

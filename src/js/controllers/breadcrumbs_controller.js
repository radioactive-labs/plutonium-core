import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="breadcrumbs"
//
// Folds the middle of the trail into an overflow menu, but only as far as it
// has to: segments are measured and dropped left-to-right until the trail fits
// on one line. The dashboard link and the current record always survive.
//
// This is deliberately width-driven rather than breakpoint-driven — a trail
// with one short segment fits fine on a phone, and a trail with a long record
// title can overflow a laptop. A media query can't tell those apart.
//
// Every segment is `shrink-0` so measurements reflect natural widths and real
// overflow is detectable. Only once everything foldable is folded do we let the
// final segment shrink and ellipsize, as a last resort.
export default class extends Controller {
  static targets = ["list", "item", "last", "overflow", "menuItem"]

  connect() {
    // The dropdown controller teleports its menu to <body> while open, which
    // moves these rows out of our scope — hold direct references so a resize
    // mid-open doesn't throw.
    this.menuItems = this.menuItemTargets

    this.observer = new ResizeObserver(() => this.reflow())
    this.observer.observe(this.element)
    this.reflow()

    // Web fonts land after first paint and change every measurement.
    document.fonts?.ready.then(() => this.reflow())
  }

  disconnect() {
    this.observer?.disconnect()
  }

  reflow() {
    if (!this.hasListTarget) return

    // Reset to "everything inline" so we measure natural widths, not the
    // previous pass's decisions.
    this.itemTargets.forEach((el) => this.#show(el))
    if (this.hasOverflowTarget) this.#hide(this.overflowTarget)
    if (this.hasLastTarget) this.lastTarget.classList.add("shrink-0")

    if (this.#overflows()) {
      // A trail with a single segment has nothing foldable and so no control.
      if (this.hasOverflowTarget) {
        // The control takes room too, so it has to be in place before we
        // measure whether folding a given segment was enough.
        this.#show(this.overflowTarget)

        for (const item of this.itemTargets) {
          if (!this.#overflows()) break
          this.#hide(item)
        }
      }

      // Nothing left to fold and it still doesn't fit: let the current record
      // ellipsize rather than push the trail off-screen.
      if (this.#overflows() && this.hasLastTarget) {
        this.lastTarget.classList.remove("shrink-0")
      }
    }

    this.#syncMenu()
  }

  #overflows() {
    return this.listTarget.scrollWidth > this.listTarget.clientWidth
  }

  #show(el) {
    el.classList.remove("hidden")
    el.classList.add("flex")
  }

  #hide(el) {
    el.classList.remove("flex")
    el.classList.add("hidden")
  }

  // A menu row is shown exactly when its inline twin has been folded away.
  #syncMenu() {
    if (!this.hasOverflowTarget) return

    const folded = this.itemTargets.map((el) => el.classList.contains("hidden"))

    this.menuItems.forEach((row, i) => {
      row.classList.toggle("hidden", !folded[i])
    })

    if (!folded.some(Boolean)) this.#hide(this.overflowTarget)
  }
}

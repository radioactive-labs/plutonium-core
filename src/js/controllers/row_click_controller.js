import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="row-click"
//
// Makes a table row or grid card behave like the resource's Show
// affordance: clicking anywhere except a real interactive element
// triggers the row's existing Show button. Single source of truth for
// the URL — turbo-frame targets, modal opening, and any other
// configuration on the Show action are inherited automatically.
//
// Mark the show element with `data-row-click-target="show"`.
// Opt out of triggering for a specific element with
// `data-row-click-ignore`.
export default class extends Controller {
  click(event) {
    if (event.target.closest("a, button, input, label, select, textarea, [data-row-click-ignore]")) {
      return
    }
    this.element.querySelector('[data-row-click-target="show"]')?.click()
  }
}

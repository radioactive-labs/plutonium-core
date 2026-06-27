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

    const show = this.element.querySelector('[data-row-click-target="show"]')
    if (!show) return

    // Modifier-click (⌘/Ctrl) or middle-click opens the record's full page in a
    // new tab — the standard "open in new tab" gesture — instead of following
    // the show link's configured target (which may be a modal frame). A new
    // browsing context sends no Turbo-Frame header, so it renders full-page.
    if (event.metaKey || event.ctrlKey || event.button === 1) {
      window.open(show.href, "_blank", "noopener")
      return
    }

    show.click()
  }
}

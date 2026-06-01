import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="capture-url"
//
// The server never sees URL fragments (#tab-id), so a server-rendered
// `return_to` can't include the one the user is currently on. On connect we
// graft the live fragment onto this element's EXISTING value — we do not
// replace the value's path/query.
//
// Replacing the whole value (an earlier approach) broke modals: the element
// already holds the correct return target (e.g. the resource page), while the
// live browser URL may be the modal/action URL. Overwriting it sent a
// successful submit "back" to the bare action form — a blank page. Keeping the
// server value and only contributing the fragment is correct in every case.
export default class extends Controller {
  connect() {
    if (!("value" in this.element)) return

    const base = this.element.value
    if (!base) return // no explicit return target; let the controller decide

    const { hash } = window.location
    if (!hash) return // no fragment to recover; keep the server value as-is

    this.element.value = base.split("#")[0] + hash
  }
}

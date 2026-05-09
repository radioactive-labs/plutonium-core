import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="view-switcher"
// Persists the user's chosen index view in a cookie so the server can
// render the right shape on next request. Reload after writing so the
// page comes back with everything (toolbar, filters, table/grid)
// matching the new view.
export default class extends Controller {
  static values = { cookieName: String, cookiePath: { type: String, default: "/" } }

  select(event) {
    const view = event.params.view
    if (!view || !this.cookieNameValue) return

    // 1 year, scoped to the portal's mount path so different portals
    // can hold different view preferences for the same resource.
    // SameSite=Lax keeps it on top-level navigations but blocks
    // cross-site requests from carrying it along.
    const maxAge = 60 * 60 * 24 * 365
    const path = this.cookiePathValue || "/"
    document.cookie = `${this.cookieNameValue}=${encodeURIComponent(view)}; Path=${path}; Max-Age=${maxAge}; SameSite=Lax`

    // Strip any legacy `?view=` param so the cookie is the source of
    // truth from now on.
    const url = new URL(window.location.href)
    url.searchParams.delete("view")
    window.location.href = url.toString()
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resource-select"
// Backend-driven typeahead. The host element is a <select> rendered by
// ResourceSelect; this controller debounces input, fetches the
// typeahead endpoint, and rewrites the <option> list.
//
// Values:
//   url             - typeahead endpoint, e.g. "/admin/users/typeahead/input/author"
//   debounceMs      - input debounce window (default 250)
//   minChars        - minimum query length to fire a request (default 0)
export default class extends Controller {
  static values = {
    url: String,
    debounceMs: { type: Number, default: 250 },
    minChars: { type: Number, default: 0 }
  }

  connect() {
    this._timer = null
    this._abort = null
    this._lastQuery = null
    this._onInput = this._onInput.bind(this)
    this.element.addEventListener("input", this._onInput)
    // Initial population for empty query so the dropdown isn't blank.
    this._fetch("")
  }

  disconnect() {
    this.element.removeEventListener("input", this._onInput)
    if (this._timer) clearTimeout(this._timer)
    if (this._abort) this._abort.abort()
  }

  _onInput(event) {
    const query = (event.target.value || "").toString()
    if (query === this._lastQuery) return
    if (query.length < this.minCharsValue) return
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(() => this._fetch(query), this.debounceMsValue)
  }

  async _fetch(query) {
    if (!this.urlValue) return
    if (this._abort) this._abort.abort()
    this._abort = new AbortController()
    this._lastQuery = query

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)

    try {
      const res = await fetch(url.toString(), {
        headers: { "Accept": "application/json" },
        signal: this._abort.signal
      })
      if (!res.ok) throw new Error(`typeahead fetch failed: ${res.status}`)
      const json = await res.json()
      this._populate(json.results || [], !!json.has_more)
    } catch (e) {
      if (e.name === "AbortError") return
      // Leave existing options in place; surface failure for ops.
      console.warn("[resource-select] typeahead error", e)
    }
  }

  _populate(results, hasMore) {
    const select = this.element.tagName === "SELECT" ? this.element : this.element.querySelector("select")
    if (!select) return

    // Preserve currently selected option(s) so the value survives a
    // refresh that doesn't include them in `results`.
    const selectedValues = new Set(Array.from(select.selectedOptions).map(o => o.value))
    const selectedFragments = Array.from(select.selectedOptions).map(o => o.cloneNode(true))

    select.innerHTML = ""
    selectedFragments.forEach(o => select.appendChild(o))

    for (const row of results) {
      if (selectedValues.has(row.value)) continue
      const opt = document.createElement("option")
      opt.value = row.value
      opt.textContent = row.label
      select.appendChild(opt)
    }

    if (hasMore) {
      const hint = document.createElement("option")
      hint.disabled = true
      hint.textContent = "More results — keep typing to refine"
      select.appendChild(hint)
    }

    // Notify any host (e.g. slim-select) that the option list changed.
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }
}

// Translations for Plutonium's bundled JavaScript.
//
// Rails serialises the `plutonium.js` subtree of the current locale into
// `<script type="application/json" id="pu-i18n">` in the layout head (see
// Plutonium::UI::Layout::Base#render_i18n). This module reads that blob
// lazily, so host apps override any string by defining the key in their own
// config/locales, exactly as they do for Plutonium's Ruby-side strings.
//
//   t("plutonium.js.clipboard.copied")                       // "Copied!"
//   t("plutonium.js.attachment_input.delete_all", {count: 3}) // "Delete 3"
//   t("plutonium.js.libraries.slim_select")                   // {placeholderText: ...} or the key
//
// Lookup rules mirror I18n: `%{name}` placeholders are interpolated from
// `params`; a `count` param picks the `one` / `other` subkey when the value
// is a plural object; a missing key falls back to the key itself.

const PREFIX = "plutonium.js."
const BLOB_ID = "pu-i18n"

let dictionary = null

function load() {
  if (typeof document === "undefined") return {}
  const el = document.getElementById(BLOB_ID)
  if (!el) return {}
  try {
    return JSON.parse(el.textContent) || {}
  } catch (e) {
    console.warn("[plutonium] could not parse #pu-i18n", e)
    return {}
  }
}

// Raw value for a key (string, plural object, library object) or undefined.
export function lookup(key) {
  if (dictionary === null) dictionary = load()
  const path = key.startsWith(PREFIX) ? key.slice(PREFIX.length) : key
  return path.split(".").reduce(
    (node, part) => (node != null && typeof node === "object" ? node[part] : undefined),
    dictionary
  )
}

function interpolate(text, params) {
  return text.replace(/%\{(\w+)\}/g, (match, name) =>
    Object.prototype.hasOwnProperty.call(params, name) ? String(params[name]) : match
  )
}

export function t(key, params = {}) {
  let value = lookup(key)

  if (value != null && typeof value === "object" && "count" in params) {
    value = params.count === 1 ? value.one : value.other
  }

  if (typeof value === "string") return interpolate(value, params)
  return value === undefined ? key : value
}

// Turbo Drive merges the head's id'd elements on navigation and swaps the
// locale blob when the locale changes, so drop the cache after each render.
if (typeof document !== "undefined") {
  const reset = () => { dictionary = null }
  document.addEventListener("turbo:load", reset)
  document.addEventListener("turbo:render", reset)
}

export default t

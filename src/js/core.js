import registerControllers from "./controllers/register_controllers.js"
import { t } from "./i18n.js"
export { registerControllers, t }

// Expose the translator so host apps (and inline scripts) can reuse the
// `plutonium.js.*` strings without importing the bundle.
if (typeof window !== "undefined") {
  window.Plutonium = window.Plutonium || {}
  window.Plutonium.t = t
}

import "./turbo"

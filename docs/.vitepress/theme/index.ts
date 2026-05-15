import DefaultTheme from "vitepress/theme"
import "./custom.css"

import HomeHero from "./components/HomeHero.vue"

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component("HomeHero", HomeHero)
  }
}

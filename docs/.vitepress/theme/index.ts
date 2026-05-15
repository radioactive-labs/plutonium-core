import DefaultTheme from "vitepress/theme"
import "./custom.css"

import HomeHero from "./components/HomeHero.vue"
import HomeStopWriting from "./components/HomeStopWriting.vue"

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component("HomeHero", HomeHero)
    app.component("HomeStopWriting", HomeStopWriting)
  }
}

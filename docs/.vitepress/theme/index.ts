import DefaultTheme from "vitepress/theme"
import "./custom.css"

import HomeHero from "./components/HomeHero.vue"
import HomeStopWriting from "./components/HomeStopWriting.vue"
import HomePillars from "./components/HomePillars.vue"
import HomeWalkthrough from "./components/HomeWalkthrough.vue"

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component("HomeHero", HomeHero)
    app.component("HomeStopWriting", HomeStopWriting)
    app.component("HomePillars", HomePillars)
    app.component("HomeWalkthrough", HomeWalkthrough)
  }
}

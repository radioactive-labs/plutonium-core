import DefaultTheme from "vitepress/theme"
import { onMounted, watch, nextTick } from "vue"
import { useRoute } from "vitepress"
import mediumZoom from "medium-zoom"
import "./custom.css"

import HomeHero from "./components/HomeHero.vue"
import HomeStopWriting from "./components/HomeStopWriting.vue"
import HomePillars from "./components/HomePillars.vue"
import HomeWalkthrough from "./components/HomeWalkthrough.vue"
import HomeFeatureTour from "./components/HomeFeatureTour.vue"
import HomeAudienceSplit from "./components/HomeAudienceSplit.vue"
import HomeInTheBox from "./components/HomeInTheBox.vue"
import HomeCta from "./components/HomeCta.vue"
import SectionLanding from "./components/SectionLanding.vue"

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component("HomeHero", HomeHero)
    app.component("HomeStopWriting", HomeStopWriting)
    app.component("HomePillars", HomePillars)
    app.component("HomeWalkthrough", HomeWalkthrough)
    app.component("HomeFeatureTour", HomeFeatureTour)
    app.component("HomeAudienceSplit", HomeAudienceSplit)
    app.component("HomeInTheBox", HomeInTheBox)
    app.component("HomeCta", HomeCta)
    app.component("SectionLanding", SectionLanding)
  },
  setup() {
    const route = useRoute()

    let closeBtn: HTMLButtonElement | null = null

    const attachCloseButton = (z: ReturnType<typeof mediumZoom>) => {
      z.on("opened", () => {
        const overlay = document.querySelector<HTMLElement>(".medium-zoom-overlay")
        if (!overlay) return
        closeBtn = document.createElement("button")
        closeBtn.type = "button"
        closeBtn.setAttribute("aria-label", "Close")
        closeBtn.className = "pu-zoom-close"
        closeBtn.innerHTML = "&times;"
        closeBtn.addEventListener("click", () => z.close())
        document.body.appendChild(closeBtn)
      })
      z.on("close", () => {
        closeBtn?.remove()
        closeBtn = null
      })
    }

    const zoom = () => {
      const z = mediumZoom(".vp-doc img:not(a img), img.pu-zoomable", {
        background: "var(--vp-c-bg)",
        margin: 16,
      })
      attachCloseButton(z)
    }
    onMounted(() => nextTick(zoom))
    watch(() => route.path, () => nextTick(zoom))
  }
}

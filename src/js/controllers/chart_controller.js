import { Controller } from "@hotwired/stimulus"
import { t } from "../i18n.js"

// Connects to data-controller="chart"
//
// Draws a Chartkick chart from data attributes rendered by
// Plutonium::UI::Dashboard::Chart:
//
//   data-chart-type-value    — Chartkick constructor ("LineChart", "PieChart", ...)
//   data-chart-data-value    — JSON: {label: value}, [[label, value], ...] or [{name, data}, ...]
//   data-chart-options-value — JSON: Chartkick options passed through from the card
//   data-chart-script-value  — URL of the charts bundle, injected once per page
//
// The bundle is loaded on demand so pages without a chart never pay for
// Chart.js. Colors and text default to Plutonium's design tokens and are
// re-read when the color mode flips, so a chart matches the theme in both modes.

const PALETTE_SIZE = 8
let libraryPromise = null

function loadLibrary(src) {
  if (window.Chartkick && window.Chartkick.adapters.length > 0) return Promise.resolve(window.Chartkick)
  if (libraryPromise) return libraryPromise

  libraryPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[src="${src}"]`)
    const script = existing || document.createElement("script")

    const settle = () => {
      if (window.Chartkick) resolve(window.Chartkick)
      else reject(new Error("[plutonium] the charts bundle loaded but defined no Chartkick"))
    }

    script.addEventListener("load", settle, { once: true })
    script.addEventListener("error", () => {
      libraryPromise = null
      reject(new Error(`[plutonium] could not load the charts bundle from ${src}`))
    }, { once: true })

    if (!existing) {
      script.src = src
      script.async = true
      script.dataset.turboTrack = "reload"
      document.head.appendChild(script)
    }
  })

  return libraryPromise
}

function cssVar(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
}

function themeColors() {
  const colors = []
  for (let i = 1; i <= PALETTE_SIZE; i++) {
    const color = cssVar(`--pu-chart-${i}`)
    if (color) colors.push(color)
  }
  return colors
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function deepMerge(base, extra) {
  const out = { ...base }
  for (const [key, value] of Object.entries(extra || {})) {
    out[key] = isPlainObject(value) && isPlainObject(out[key]) ? deepMerge(out[key], value) : value
  }
  return out
}

export default class extends Controller {
  static values = {
    type: { type: String, default: "LineChart" },
    data: String,
    options: Object,
    script: String
  }

  connect() {
    this.render = this.render.bind(this)
    this.observer = new MutationObserver((mutations) => {
      if (mutations.some((m) => m.attributeName === "class")) this.render()
    })
    this.observer.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })

    this.element.addEventListener("turbo:morph-element", this.render)

    loadLibrary(this.scriptValue)
      .then(() => this.render())
      .catch((error) => {
        console.error(error)
        this.element.textContent = t("plutonium.js.charts.failed")
      })
  }

  disconnect() {
    this.observer?.disconnect()
    this.element.removeEventListener("turbo:morph-element", this.render)
    this.#destroy()
  }

  dataValueChanged() { this.render() }
  optionsValueChanged() { this.render() }

  render() {
    const Chartkick = window.Chartkick
    if (!Chartkick || !this.element.isConnected) return

    const Klass = Chartkick[this.typeValue]
    if (!Klass) {
      console.error(`[plutonium] unknown chart type ${this.typeValue}`)
      return
    }

    this.#destroy()
    this.element.replaceChildren()
    this.chart = new Klass(this.element, this.#data(), this.#options())
  }

  #destroy() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  #data() {
    try {
      return JSON.parse(this.dataValue || "[]")
    } catch (error) {
      console.error("[plutonium] chart data is not valid JSON", error)
      return []
    }
  }

  // Plutonium's defaults, with the card's own options merged over them.
  // Axis styling only applies to cartesian charts: handing a pie chart
  // `scales` makes Chart.js draw axes around it.
  #options() {
    const text = cssVar("--pu-text-muted")
    const grid = cssVar("--pu-border")
    const surface = cssVar("--pu-card-bg")
    const library = { color: text }

    if (this.typeValue === "PieChart") {
      library.elements = { arc: { borderColor: surface } }
    } else {
      library.scales = {
        x: { ticks: { color: text }, grid: { color: grid }, border: { color: grid } },
        y: { ticks: { color: text }, grid: { color: grid }, border: { color: grid } }
      }
    }

    const defaults = { colors: themeColors(), empty: t("plutonium.js.charts.empty"), library }
    return deepMerge(defaults, this.optionsValue)
  }
}

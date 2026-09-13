// The on-demand charts bundle: Chart.js wired into Chartkick.
//
// Built as its own entry point (app/assets/plutonium-charts.js) and NOT
// imported by plutonium.js, so pages without a chart never download it. The
// `chart` Stimulus controller injects this script the first time a chart card
// connects (its URL rides the card's data-chart-script-value) and then draws
// through `window.Chartkick`.
import Chartkick from "chartkick"
import "chartkick/chart.js"

if (typeof window !== "undefined") {
  window.Chartkick = Chartkick
}

export default Chartkick

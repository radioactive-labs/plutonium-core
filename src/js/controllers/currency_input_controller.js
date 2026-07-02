import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="currency-input"
//
// Pads a currency input's left edge to exactly clear its overlaid unit prefix.
//
// The prefix ("$", "£", "GH₵", "USD", …) is absolutely positioned at the
// field's left edge; its width varies by symbol AND font, so any fixed padding
// is wrong for some currency — too little clips a wide prefix (digits collide
// with it, as with "GH₵"), too much wastes space on a bare "$". This measures
// the rendered prefix and sets padding-left to match, so the caret always sits
// just past the symbol regardless of currency or typeface.
//
// DOM contract:
//   wrapper  data-controller="currency-input"
//   prefix   data-currency-input-target="prefix"   (the overlaid unit span)
//   input    data-currency-input-target="field"    (the number input)
export default class extends Controller {
  static targets = ["prefix", "field"]
  // Space between the prefix and the first digit, in px.
  static values = { gap: { type: Number, default: 6 } }

  connect() {
    this.#pad()
    // Web fonts often load after connect; the fallback font's metrics differ,
    // so re-measure once they're ready to correct the padding.
    document.fonts.ready.then(() => this.#pad())
  }

  #pad() {
    // Inline !important so it beats pu-input's own left padding (a plain class
    // would lose the cascade — see the note this replaces in currency.rb).
    this.fieldTarget.style.setProperty(
      "padding-left",
      `${this.prefixTarget.offsetWidth + this.gapValue}px`,
      "important"
    )
  }
}

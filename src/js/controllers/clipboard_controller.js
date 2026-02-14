import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copy(event) {
    const text = this.sourceTarget.value || this.sourceTarget.textContent
    const button = event.currentTarget
    const originalText = button.textContent

    navigator.clipboard.writeText(text).then(() => {
      button.textContent = "Copied!"
      setTimeout(() => {
        button.textContent = originalText
      }, 2000)
    }).catch((err) => {
      // Fallback for browsers that don't support clipboard API
      console.warn("Clipboard API failed, using fallback:", err)
      this.fallbackCopy(text)
      button.textContent = "Copied!"
      setTimeout(() => {
        button.textContent = originalText
      }, 2000)
    })
  }

  fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
  }
}

import { Controller } from "@hotwired/stimulus"
import DOMPurify from 'dompurify';
import { marked } from 'marked';

// Connects to data-controller="easymde"
export default class extends Controller {
  connect() {
    console.log(`easymde connected: ${this.element}`)
    this.easyMDE = new EasyMDE(this.#buildOptions())
    this.element.setAttribute("data-action", "turbo:morph-element->easymde#reconnect")
  }

  disconnect() {
    this.easyMDE.toTextArea()
    this.easyMDE = null
  }

  reconnect() {
    this.disconnect()
    this.connect()
  }

  #buildOptions() {
    let options = {
      element: this.element,
      promptURLs: true,
      spellChecker: false,
      // Override the default preview renderer
      previewRender: (plainText) => {
        // First sanitize the input to remove any undesired HTML
        const cleanedText = DOMPurify.sanitize(plainText, {
          ALLOWED_TAGS: ['strong', 'em', 'sub', 'sup', 'details', 'summary'],
          ALLOWED_ATTR: []
        });

        // Then convert markdown to HTML
        const cleanedHTML = marked(cleanedText);

        // Finally, another pass, since marked does not sanitize html
        return DOMPurify.sanitize(cleanedHTML, { USE_PROFILES: { html: true } })
      }
    }
    if (this.element.attributes.id.value) {
      options.autosave = {
        enabled: true,
        uniqueId: this.element.attributes.id.value,
        delay: 1000,
      }
    }
    return options
  }
}

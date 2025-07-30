import { Controller } from "@hotwired/stimulus"
import DOMPurify from 'dompurify';
import { marked } from 'marked';

// Connects to data-controller="easymde"
export default class extends Controller {
  static targets = ["textarea"]
  
  connect() {
    if (this.easyMDE) return
    
    this.originalValue = this.element.value
    this.easyMDE = new EasyMDE(this.#buildOptions())
    
    // Store the editor content before morphing
    this.element.addEventListener("turbo:before-morph-element", (event) => {
      if (event.target === this.element && this.easyMDE) {
        this.storedValue = this.easyMDE.value()
      }
    })
    
    // Restore after morphing
    this.element.addEventListener("turbo:morph-element", (event) => {
      if (event.target === this.element) {
        requestAnimationFrame(() => this.#handleMorph())
      }
    })
  }

  disconnect() {
    if (this.easyMDE) {
      try {
        // Only call toTextArea if the element is still in the DOM
        if (this.element.isConnected && this.element.parentNode) {
          this.easyMDE.toTextArea()
        }
      } catch (error) {
        console.warn('EasyMDE cleanup error:', error)
      }
      this.easyMDE = null
    }
  }
  
  #handleMorph() {
    if (!this.element.isConnected) return
    
    // Don't call toTextArea during morph - just clean up references
    if (this.easyMDE) {
      // Skip toTextArea cleanup - it causes DOM errors during morphing
      this.easyMDE = null
    }
    
    // Recreate the editor
    this.easyMDE = new EasyMDE(this.#buildOptions())
    
    // Restore the stored value if we have it
    if (this.storedValue !== undefined) {
      this.easyMDE.value(this.storedValue)
      this.storedValue = undefined
    }
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

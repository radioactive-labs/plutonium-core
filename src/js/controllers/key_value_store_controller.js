import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="key-value-store"
export default class extends Controller {
  static targets = ["container", "pair", "template", "addButton", "keyInput", "valueInput"]
  static values = { limit: Number }

  connect() {
    this.updateIndices()
    this.updateAddButtonState()
  }

  addPair(event) {
    event.preventDefault()

    if (this.pairTargets.length >= this.limitValue) {
      return
    }

    const template = this.templateTarget
    const newPair = template.content.cloneNode(true)
    const index = this.pairTargets.length

    // Update the template placeholders with actual indices
    this.updatePairIndices(newPair, index)

    this.containerTarget.appendChild(newPair)
    this.updateIndices()
    this.updateAddButtonState()

    // Focus on the key input of the new pair
    const newKeyInput = this.containerTarget.lastElementChild.querySelector('[data-key-value-store-target="keyInput"]')
    if (newKeyInput) {
      newKeyInput.focus()
    }
  }

  removePair(event) {
    event.preventDefault()

    const pair = event.target.closest('[data-key-value-store-target="pair"]')
    if (pair) {
      pair.remove()
      this.updateIndices()
      this.updateAddButtonState()
    }
  }

  updateIndices() {
    this.pairTargets.forEach((pair, index) => {
      const keyInput = pair.querySelector('[data-key-value-store-target="keyInput"]')
      const valueInput = pair.querySelector('[data-key-value-store-target="valueInput"]')

      if (keyInput) {
        keyInput.name = keyInput.name.replace(/\[\d+\]/, `[${index}]`)
        keyInput.id = keyInput.id.replace(/_\d+_/, `_${index}_`)
      }
      if (valueInput) {
        valueInput.name = valueInput.name.replace(/\[\d+\]/, `[${index}]`)
        valueInput.id = valueInput.id.replace(/_\d+_/, `_${index}_`)
      }
    })
  }

  updatePairIndices(element, index) {
    const inputs = element.querySelectorAll('input')
    inputs.forEach(input => {
      if (input.name) {
        input.name = input.name.replace('__INDEX__', index)
      }
      if (input.id) {
        input.id = input.id.replace('___INDEX___', `_${index}_`)
      }
    })
  }

  updateAddButtonState() {
    const addButton = this.addButtonTarget
    if (this.pairTargets.length >= this.limitValue) {
      addButton.disabled = true
      addButton.classList.add('opacity-50', 'cursor-not-allowed')
    } else {
      addButton.disabled = false
      addButton.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  // Serialize the current key-value pairs to JSON
  toJSON() {
    const pairs = {}
    this.pairTargets.forEach(pair => {
      const keyInput = pair.querySelector('[data-key-value-store-target="keyInput"]')
      const valueInput = pair.querySelector('[data-key-value-store-target="valueInput"]')

      if (keyInput && valueInput && keyInput.value.trim()) {
        pairs[keyInput.value.trim()] = valueInput.value
      }
    })
    return JSON.stringify(pairs)
  }

  // Get the current key-value pairs as an object
  toObject() {
    const pairs = {}
    this.pairTargets.forEach(pair => {
      const keyInput = pair.querySelector('[data-key-value-store-target="keyInput"]')
      const valueInput = pair.querySelector('[data-key-value-store-target="valueInput"]')

      if (keyInput && valueInput && keyInput.value.trim()) {
        pairs[keyInput.value.trim()] = valueInput.value
      }
    })
    return pairs
  }
}

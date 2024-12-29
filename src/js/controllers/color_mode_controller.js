import { Controller } from "@hotwired/stimulus"


// Connects to data-controller="color-mode"
export default class extends Controller {
  // static targets = ["trigger", "menu"]

  connect() {
    this.updateColorMode()
  }

  disconnect() {
  }

  updateColorMode() {
    if (localStorage.theme === 'dark' || (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }

  setLightColorMode() {
    // Whenever the user explicitly chooses light mode
    localStorage.theme = 'light'
    this.updateColorMode()
  }

  setDarkColorMode() {
    // Whenever the user explicitly chooses dark mode
    localStorage.theme = 'dark'
    this.updateColorMode()
  }

  setSystemColorMode() {
    // Whenever the user explicitly chooses to respect the OS preference
    localStorage.removeItem('theme')
    this.updateColorMode()
  }
}

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="color-mode"
export default class extends Controller {
  static values = { current: String };

  connect() {
    // Set initial mode from localStorage or default
    const mode = localStorage.getItem('theme') || "light";
    this.setMode(mode);

    // Listen for cross-tab theme changes
    this.handleStorageChange = (e) => {
      console.log('Storage event received in color-mode controller:', e.key, e.newValue, e.oldValue)
      if (e.key === 'theme' && e.newValue) {
        console.log('Updating color-mode theme to:', e.newValue)
        this.setMode(e.newValue);
      }
    };
    window.addEventListener('storage', this.handleStorageChange);
  }

  disconnect() {
    // Clean up event listener
    window.removeEventListener('storage', this.handleStorageChange);
  }

  toggleMode() {
    const current = this.currentValue || "light";
    const next = current === "light" ? "dark" : "light";
    this.setMode(next);
  }

  setMode(mode) {
    // Update html class
    if (mode === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }

    // Update button state
    this.currentValue = mode;

    this.dispatch("changed", { detail: { mode }, target: document });

    // Show/hide icons
    this.toggleIcons(mode);

    // Store in localStorage to trigger storage events in other tabs
    localStorage.setItem('theme', mode);
  }

  toggleIcons(mode) {
    const sun = this.element.querySelector(".color-mode-icon-light");
    const moon = this.element.querySelector(".color-mode-icon-dark");

    if (sun && moon) {
      if (mode === "light") {
        sun.classList.remove("hidden");
        moon.classList.add("hidden");
      } else {
        sun.classList.add("hidden");
        moon.classList.remove("hidden");
      }
    }
  }
}

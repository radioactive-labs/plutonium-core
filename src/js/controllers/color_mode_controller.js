import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="color-mode"
export default class extends Controller {
  static values = { current: String };

  connect() {
    // Set initial mode from localStorage or default
    const mode = localStorage.theme || "light";
    this.setMode(mode);
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
      localStorage.theme = "dark";
    } else {
      document.documentElement.classList.remove("dark");
      localStorage.theme = "light";
    }

    // Update button state
    this.currentValue = mode;

    this.dispatch("changed", { detail: { mode }, target: document });

    // Show/hide icons
    this.toggleIcons(mode);
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

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="color-mode"
//
// Shared theme state across the app. localStorage key 'theme' holds one of:
//   'auto'  — follow prefers-color-scheme (default when unset)
//   'light' — force light
//   'dark'  — force dark
const ORDER = ['auto', 'light', 'dark'];

export default class extends Controller {
  static values = { current: String };

  connect() {
    this.applyMode(this.readMode());

    this.handleStorageChange = (e) => {
      if (e.key === 'theme') this.applyMode(this.readMode());
    };
    window.addEventListener('storage', this.handleStorageChange);

    this.mq = window.matchMedia('(prefers-color-scheme: dark)');
    this.handleMqChange = () => {
      if (this.readMode() === 'auto') this.applyMode('auto');
    };
    this.mq.addEventListener('change', this.handleMqChange);
  }

  disconnect() {
    window.removeEventListener('storage', this.handleStorageChange);
    if (this.mq) this.mq.removeEventListener('change', this.handleMqChange);
  }

  toggleMode() {
    const current = this.readMode();
    const next = ORDER[(ORDER.indexOf(current) + 1) % ORDER.length];
    this.setMode(next);
  }

  setMode(mode) {
    localStorage.setItem('theme', mode);
    this.applyMode(mode);
  }

  applyMode(mode) {
    const effective = this.effectiveMode(mode);
    document.documentElement.classList.toggle('dark', effective === 'dark');
    this.currentValue = mode;
    this.toggleIcons(mode);
  }

  readMode() {
    const saved = localStorage.getItem('theme');
    return ORDER.includes(saved) ? saved : 'auto';
  }

  effectiveMode(mode) {
    if (mode === 'light' || mode === 'dark') return mode;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  toggleIcons(mode) {
    const icons = {
      auto: this.element.querySelector(".color-mode-icon-auto"),
      light: this.element.querySelector(".color-mode-icon-light"),
      dark: this.element.querySelector(".color-mode-icon-dark"),
    };
    for (const [key, el] of Object.entries(icons)) {
      if (!el) continue;
      el.classList.toggle("hidden", key !== mode);
    }
  }
}

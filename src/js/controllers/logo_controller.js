import { Controller } from "@hotwired/stimulus";

// connects to data-controller="logo"
export default class extends Controller {
  static targets = ["light", "dark"];

  connect() {
    const dark = document.documentElement.classList.contains("dark");
    this.toggleLogo(dark);
  }

  updateFromEvent({ detail: { mode } }) {
    this.toggleLogo(mode === "dark");
  }

  toggleLogo(dark) {
    this.lightTarget.hidden = dark;
    this.darkTarget.hidden = !dark;
  }
}

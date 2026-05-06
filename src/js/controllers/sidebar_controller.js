import { Controller } from "@hotwired/stimulus";

// Persists across controller reconnects so the value saved on
// turbo:before-render is still available on turbo:render, even though
// the <aside> hosting this controller is replaced during navigation.
let savedScrollTop = 0;

export default class extends Controller {
  static targets = ["scroll"];

  connect() {
    this.beforeRender = this.beforeRender.bind(this);
    this.afterRender = this.afterRender.bind(this);
    document.addEventListener("turbo:before-render", this.beforeRender);
    document.addEventListener("turbo:render", this.afterRender);
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.beforeRender);
    document.removeEventListener("turbo:render", this.afterRender);
  }

  beforeRender() {
    if (this.hasScrollTarget) savedScrollTop = this.scrollTarget.scrollTop;
  }

  afterRender() {
    if (this.hasScrollTarget) this.scrollTarget.scrollTop = savedScrollTop;
  }
}

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="remote-modal"
// Drives the open/close lifecycle of a turbo-fetched <dialog>.
//
// Entry is animated by deferring `data-open` to the frame after
// showModal() — the dialog renders one frame with its closed-state
// transform/opacity, then transitions into the open state. Exit
// reverses it: remove `data-open`, wait for the dialog's animations
// to settle, then call close(). This avoids the @starting-style /
// allow-discrete spec dance, which is unreliable across browsers.
export default class extends Controller {
  connect() {
    this.originalScrollPosition = window.scrollY;
    this.originalOverflow = document.body.style.overflow;
    this.bodyStateRestored = false;
    this._closing = false;
    document.body.style.overflow = "hidden";

    this.element.showModal();
    // Double rAF ensures the closed-state styles paint before we flip
    // data-open, so the transition actually fires.
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.setAttribute("data-open", "");
      });
    });

    this.onCancel = this.#onCancel.bind(this);
    this.onClose = this.#onClose.bind(this);
    this.onRequestClose = () => this.#animateClose();

    this.element.addEventListener("cancel", this.onCancel);
    this.element.addEventListener("close", this.onClose);
    this.element.addEventListener("modal:request-close", this.onRequestClose);
  }

  disconnect() {
    this.element.removeEventListener("cancel", this.onCancel);
    this.element.removeEventListener("close", this.onClose);
    this.element.removeEventListener("modal:request-close", this.onRequestClose);
    this.#restoreBodyState();
  }

  close() {
    this.#animateClose();
  }

  #onCancel(event) {
    // Another listener (typically dirty-form-guard) already handled
    // this — don't double-process.
    if (event.defaultPrevented) return;
    event.preventDefault();
    this.#animateClose();
  }

  #onClose() {
    this.#restoreBodyState();
  }

  async #animateClose() {
    if (this._closing) return;
    this._closing = true;

    this.element.removeAttribute("data-open");

    const animations = this.element.getAnimations({ subtree: true });
    await Promise.allSettled(animations.map((a) => a.finished));

    this.element.close();
  }

  #restoreBodyState() {
    if (this.bodyStateRestored) return;
    this.bodyStateRestored = true;
    document.body.style.overflow = this.originalOverflow || "";
    window.scrollTo(0, this.originalScrollPosition);
  }
}

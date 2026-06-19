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
    this.onLightDismiss = this.#onLightDismiss.bind(this);

    this.element.addEventListener("cancel", this.onCancel);
    this.element.addEventListener("close", this.onClose);
    this.element.addEventListener("modal:request-close", this.onRequestClose);
    this.element.addEventListener("click", this.onLightDismiss);
  }

  disconnect() {
    this.element.removeEventListener("cancel", this.onCancel);
    this.element.removeEventListener("close", this.onClose);
    this.element.removeEventListener("modal:request-close", this.onRequestClose);
    this.element.removeEventListener("click", this.onLightDismiss);
    this.#restoreBodyState();
  }

  close() {
    this.#animateClose();
  }

  #onCancel(event) {
    // `cancel` bubbles, so a descendant firing it — most notably an
    // <input type="file"> whose picker was dismissed — reaches this
    // listener. That is not a request to close the modal; only the
    // dialog's own cancel (Escape) targets the dialog element itself.
    if (event.target !== this.element) return;
    // Another listener (typically dirty-form-guard) already handled
    // this — don't double-process.
    if (event.defaultPrevented) return;
    event.preventDefault();
    this.#animateClose();
  }

  #onLightDismiss(event) {
    // The dialog is a full-viewport, transparent container with the panel
    // as a child, so native backdrop light-dismiss can't fire (clicks land
    // on the dialog, never on its ::backdrop). A click whose target is the
    // dialog element itself = a click in the transparent area outside the
    // panel → treat it as a dismiss. Clicks on the panel, its descendants,
    // or an uppy overlay mounted into the dialog have a different target
    // and pass through. Routed through a synthetic `cancel` so the same
    // guards as Escape (dirty-form-guard) and the #onCancel → animateClose
    // path handle it uniformly.
    if (event.target !== this.element) return;
    this.element.dispatchEvent(new Event("cancel", { cancelable: true }));
  }

  #onClose() {
    this.#restoreBodyState();
  }

  async #animateClose() {
    if (this._closing) return;
    this._closing = true;

    // Commit any in-flight enter transition to its open end-state before
    // reversing it. Removing data-open while the enter is still running
    // reverses that transition, and CSS shortens the reverse duration in
    // proportion to how far the enter got — so a quick open→close snaps
    // shut instead of animating, which reads as choppy. finish() jumps to
    // the open state so the exit always plays its full duration. The enter
    // animation lives on the panel (a descendant), so commit the whole
    // subtree — but guard each finish(): an infinite descendant animation
    // (e.g. a spinner) throws on finish() and must be left running.
    this.element.getAnimations({ subtree: true }).forEach((animation) => {
      try {
        animation.finish();
      } catch {
        /* infinite animation — leave it running */
      }
    });

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

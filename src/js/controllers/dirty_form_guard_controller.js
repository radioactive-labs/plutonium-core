import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dirty-form-guard"
// Prompts before dismissing a modal form whose contents have changed.
// Self-disables when not inside a <dialog>, so it's safe to attach to
// every form unconditionally.
//
// Esc is intercepted at the document's capture phase: relying on the
// dialog's `cancel` event alone proved flaky under rapid/held Esc when
// the parent dialog uses `closedby="any"`. The cancel listener stays
// as defense in depth.
export default class extends Controller {
  static targets = ["confirmDialog"];

  // Set by controllers, not the user — comparing them would flag
  // every form as dirty on connect (return_to) or on submit (pre_submit).
  static IGNORED_KEYS = new Set(["authenticity_token", "return_to", "pre_submit"]);

  connect() {
    this.dialog = this.element.closest("dialog");
    if (!this.dialog) return;

    this.snapshot = this.#serialize();
    this.forceClose = false;
    this.submitting = false;

    this.onCancel = this.#onCancel.bind(this);
    this.onSubmit = this.#onSubmit.bind(this);
    this.onCloseButtonClick = this.#onCloseButtonClick.bind(this);
    this.onConfirmCancel = this.#onConfirmCancel.bind(this);
    this.onKeydown = this.#onKeydown.bind(this);

    document.addEventListener("keydown", this.onKeydown, true);
    // Capture phase so this runs before remote-modal's cancel handler
    // — that way `defaultPrevented` is visible there if we intervene.
    this.dialog.addEventListener("cancel", this.onCancel, true);

    this.element.addEventListener("submit", this.onSubmit);
    this.#closeButtons().forEach((btn) =>
      btn.addEventListener("click", this.onCloseButtonClick, true),
    );

    if (this.hasConfirmDialogTarget) {
      this.confirmDialogTarget.addEventListener("cancel", this.onConfirmCancel);
    }
  }

  disconnect() {
    if (!this.dialog) return;
    document.removeEventListener("keydown", this.onKeydown, true);
    this.dialog.removeEventListener("cancel", this.onCancel, true);
    this.element.removeEventListener("submit", this.onSubmit);
    this.#closeButtons().forEach((btn) =>
      btn.removeEventListener("click", this.onCloseButtonClick, true),
    );
    if (this.hasConfirmDialogTarget) {
      this.confirmDialogTarget.removeEventListener("cancel", this.onConfirmCancel);
    }
  }

  async discard() {
    this.forceClose = true;
    await this.#closeConfirm();
    // Hand off to remote-modal so the parent modal animates out
    // instead of snapping shut.
    this.dialog.dispatchEvent(new CustomEvent("modal:request-close"));
  }

  keepEditing() {
    this.#closeConfirm();
  }

  #closeButtons() {
    if (!this.dialog) return [];
    return this.dialog.querySelectorAll('[data-action~="remote-modal#close"]');
  }

  #serialize() {
    const data = new FormData(this.element);
    const enc = encodeURIComponent;
    return [...data.entries()]
      .filter(([key]) => !this.constructor.IGNORED_KEYS.has(key))
      .map(([key, value]) => {
        const v = value instanceof File ? value.name : value;
        return `${enc(key)}=${enc(v)}`;
      })
      .sort()
      .join("&");
  }

  #isDirty() {
    return this.#serialize() !== this.snapshot;
  }

  #onSubmit() {
    this.submitting = true;
  }

  #confirmIsOpen() {
    return this.hasConfirmDialogTarget && this.confirmDialogTarget.open;
  }

  #onKeydown(event) {
    if (event.key !== "Escape") return;
    if (!this.dialog.open) return;

    // Once the confirm is open, only its buttons may close it.
    if (this.#confirmIsOpen()) {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      return;
    }

    if (this.forceClose || this.submitting) return;
    if (!this.#isDirty()) return;

    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
    this.#promptDiscard();
  }

  #onCancel(event) {
    if (this.forceClose || this.submitting) return;
    if (!this.#isDirty()) return;
    event.preventDefault();
    this.#promptDiscard();
  }

  #onCloseButtonClick(event) {
    if (this.forceClose || this.submitting) return;
    if (!this.#isDirty()) return;
    event.preventDefault();
    event.stopPropagation();
    this.#promptDiscard();
  }

  #onConfirmCancel(event) {
    event.preventDefault();
  }

  #promptDiscard() {
    if (this.hasConfirmDialogTarget) {
      const d = this.confirmDialogTarget;
      d.showModal();
      requestAnimationFrame(() => {
        requestAnimationFrame(() => d.setAttribute("data-open", ""));
      });
    } else if (window.confirm("Discard your changes?")) {
      this.forceClose = true;
      this.dialog.dispatchEvent(new CustomEvent("modal:request-close"));
    }
  }

  async #closeConfirm() {
    if (!this.hasConfirmDialogTarget) return;
    const d = this.confirmDialogTarget;
    if (!d.open) return;
    d.removeAttribute("data-open");
    const animations = d.getAnimations({ subtree: true });
    await Promise.allSettled(animations.map((a) => a.finished));
    d.close();
  }
}

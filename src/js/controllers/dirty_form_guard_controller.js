import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dirty-form-guard"
// Prompts before dismissing a modal form whose contents have changed.
// Self-disables when not inside a <dialog>, so it's safe to attach to
// every form unconditionally.
//
// Dirtiness is a diff against a baseline captured at the user's *first*
// real interaction — not at connect. Field widgets (intl-tel-input,
// flatpickr, slim-select, easymde) mutate the form *after* connect —
// injecting hidden inputs, reformatting values, replacing the native
// control — via silent `input.value = …` writes (no event) or synthetic
// events. Snapshotting at connect counted that settling as edits and
// prompted on a pristine modal.
//
// Instead:
//   • On the first *trusted* pointer/key action inside the form, serialize
//     the form into `baseline`. The user can't interact before the form has
//     rendered, so widgets have already settled — their hidden inputs and
//     reformatted values are part of the baseline, not a phantom diff. The
//     key/pointer event fires *before* the value changes, so the baseline is
//     pre-edit.
//   • On close, the form is dirty if its serialization differs from
//     `baseline`. This is independent of which events a widget dispatches
//     (or whether it dispatches any), catches widget-mediated edits the same
//     as native typing, and — being a diff — treats an edit reverted to its
//     original value as clean. No interaction → no baseline → never dirty.
//
// Esc is intercepted at the document's capture phase: relying on the
// dialog's `cancel` event alone proved flaky under rapid/held Esc when
// the parent dialog uses `closedby="any"`. The cancel listener stays
// as defense in depth.
export default class extends Controller {
  static targets = ["confirmDialog"];

  // Set by controllers, not the user — they're already present (or absent)
  // when the baseline is taken, so they never contribute to the diff; listed
  // for safety against a controller writing them mid-edit.
  static IGNORED_KEYS = new Set(["authenticity_token", "return_to", "pre_submit"]);

  // Keys that move focus or dismiss the dialog rather than edit it — they
  // must not, on their own, baseline the form.
  static NON_EDITING_KEYS = new Set([
    "Tab", "Escape", "Shift", "Control", "Alt", "Meta",
  ]);

  connect() {
    this.dialog = this.element.closest("dialog");
    if (!this.dialog) return;

    this.baseline = null;
    this.forceClose = false;
    this.submitting = false;

    this.onFirstIntent = this.#onFirstIntent.bind(this);
    this.onCancel = this.#onCancel.bind(this);
    this.onSubmit = this.#onSubmit.bind(this);
    this.onCloseButtonClick = this.#onCloseButtonClick.bind(this);
    this.onConfirmCancel = this.#onConfirmCancel.bind(this);
    this.onKeydown = this.#onKeydown.bind(this);

    // A trusted pointer/key action inside the form is the user starting to
    // edit — capture the (settled, pre-edit) baseline then. Capture phase so
    // a widget that stops propagation can't hide it from us.
    this.element.addEventListener("pointerdown", this.onFirstIntent, true);
    this.element.addEventListener("keydown", this.onFirstIntent, true);

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
    this.element.removeEventListener("pointerdown", this.onFirstIntent, true);
    this.element.removeEventListener("keydown", this.onFirstIntent, true);
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

  discard() {
    this.forceClose = true;
    // Snap the confirm shut with no exit animation, then hand straight
    // off to remote-modal so the parent modal animates out as a single,
    // smooth motion.
    //
    // Animating the confirm out *first* (the old behaviour) stuttered:
    // its fade played on top of the parent modal's still-live backdrop
    // `backdrop-filter: blur()`, forcing the compositor to re-rasterise
    // the blurred viewport every frame — and its display:none reflow
    // landed partway through the modal's own close transition. We're
    // tearing the whole modal down anyway, so the confirm doesn't need
    // its own choreography.
    this.#snapConfirmClosed();
    this.dialog.dispatchEvent(new CustomEvent("modal:request-close"));
  }

  keepEditing() {
    this.#closeConfirm();
  }

  #closeButtons() {
    if (!this.dialog) return [];
    return this.dialog.querySelectorAll('[data-action~="remote-modal#close"]');
  }

  // Capture the baseline the first time the user really touches the form —
  // a trusted pointer or editing keystroke. The form has rendered (so widgets
  // have settled) and the event fires before the value changes, so this is
  // the settled, pre-edit state. Runs once; later interactions are no-ops.
  #onFirstIntent(event) {
    if (this.baseline != null) return;
    if (!event.isTrusted) return;
    if (event.type === "keydown" && this.constructor.NON_EDITING_KEYS.has(event.key)) return;
    this.baseline = this.#serialize();
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

  // No interaction → no baseline → never dirty. Otherwise dirty iff the form
  // now serializes differently than it did at first touch (so an edit reverted
  // to its original value reads as clean).
  #isDirty() {
    return this.baseline != null && this.#serialize() !== this.baseline;
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
    // `cancel` bubbles: a descendant's cancel (e.g. an <input type="file">
    // whose picker was dismissed) reaches this listener. Only the dialog's
    // own cancel (Escape) — target === the dialog — should prompt.
    if (event.target !== this.dialog) return;
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

  // Close the confirm immediately, skipping its exit transition. Used by
  // discard(), where the parent modal is about to animate away and a
  // separate confirm fade would only stutter against the modal's live
  // backdrop blur.
  #snapConfirmClosed() {
    if (!this.hasConfirmDialogTarget) return;
    const d = this.confirmDialogTarget;
    d.removeAttribute("data-open");
    if (d.open) d.close();
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

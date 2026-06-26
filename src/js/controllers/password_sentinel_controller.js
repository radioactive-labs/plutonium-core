import { Controller } from "@hotwired/stimulus";

// Guards a password field pre-filled with the server "unchanged" sentinel — a
// stored secret the user hasn't touched, masked behind a fixed placeholder.
//
// The sentinel must be edited all-or-nothing: a partial edit (e.g. one
// backspace) would leave a truncated sentinel that no longer matches on the
// server and gets saved as a literal new password. So the first edit gesture
// replaces the whole field — Backspace/Delete empties it (keep-or-clear), a
// typed/pasted character starts a fresh value. After that first edit the field
// behaves natively.
export default class extends Controller {
  static values = { sentinel: String };

  connect() {
    this.armed = this.element.value === this.sentinelValue;
  }

  beforeinput(event) {
    if (!this.armed) return;

    // Replace the whole sentinel regardless of caret position, so a click into
    // the middle followed by a keystroke can't corrupt it.
    event.preventDefault();
    this.armed = false;

    let next = "";
    if (event.inputType === "insertText" && event.data != null) {
      next = event.data;
    } else if (event.inputType === "insertFromPaste" && event.dataTransfer) {
      next = event.dataTransfer.getData("text");
    }
    // Backspace/Delete (deleteContent*) and anything else collapse to "".

    this.element.value = next;
    this.element.setSelectionRange(next.length, next.length);
    this.element.dispatchEvent(new Event("input", { bubbles: true }));
  }
}

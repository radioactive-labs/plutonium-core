import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="slim-select"
//
// Optional values (used by the typeahead-capable ResourceSelect):
//   typeahead-url   — backend endpoint that returns
//                     {results: [{value, label}, ...], has_more: bool}.
//                     When present, SlimSelect's built-in client-side
//                     filter is replaced by a debounced fetch through
//                     this URL.
export default class extends Controller {
  static values = {
    typeaheadUrl: String,
    typeaheadDebounceMs: { type: Number, default: 200 }
  }

  connect() {
    if (this.slimSelect) return;

    this.#setupSlimSelect();

    // Just recreate SlimSelect after morphing - the DOM will have correct selections
    this.element.addEventListener("turbo:morph-element", (event) => {
      if (event.target === this.element && !this.morphing) {
        this.morphing = true;
        requestAnimationFrame(() => {
          this.#handleMorph();
          this.morphing = false;
        });
      }
    });
  }

  #setupSlimSelect() {
    const settings = {};
    this.modal = document.querySelector('[data-controller="remote-modal"]');

    if (this.modal) {
      // Inside a <dialog> opened via showModal(), the dialog lives in the
      // browser's top layer: anything rendered outside it (e.g. on
      // document.body) paints BEHIND it regardless of z-index, and the
      // dialog is transform-animated (slide/scale), so position:fixed
      // descendants are rebased to the dialog's box rather than the
      // viewport. Rendering the dropdown into the select's own container
      // (SlimSelect's other default) instead leaves it clipped by the
      // form section's overflow.
      //
      // So attach the dropdown to the dialog itself and position it
      // absolutely relative to the dialog's box (see #applyModalPositioning).
      // It then escapes every section's overflow while staying inside the
      // top layer, on top of the form. Mirrors the flatpickr controller.
      settings.contentLocation = this.modal;
      settings.contentPosition = "absolute";
      settings.openPosition = "auto";
    }

    const events = {};

    if (this.hasTypeaheadUrlValue && this.typeaheadUrlValue) {
      // Replace SlimSelect's client-side filter with a server fetch.
      // Returns the SlimSelect data array shape: {value, text}.
      events.search = (search, currentData) => this.#typeaheadFetch(search, currentData);
    }

    this.slimSelect = new SlimSelect({
      select: this.element,
      settings: settings,
      events: events,
    });

    if (this.modal) {
      this.#applyModalPositioning();
    }
  }

  // Re-base SlimSelect's dropdown positioning onto the modal's coordinate
  // system. SlimSelect computes document coordinates (rect + window scroll),
  // which are wrong for content parented to a transform-animated <dialog>:
  // an absolutely-positioned child is placed relative to the dialog's box,
  // not the document. We override the two leaf positioners so SlimSelect
  // keeps deciding up-vs-down (and its own open/scroll/resize triggers keep
  // firing), but the actual offsets are measured against the dialog. A
  // capture-phase scroll listener covers scrolls of the dialog's own
  // content, which never reach SlimSelect's window-level scroll listener.
  #applyModalPositioning() {
    const render = this.slimSelect.render;
    const openAbove = render.classes.openAbove;
    const openBelow = render.classes.openBelow;

    const place = (above) => {
      const mainEl = render.main.main;
      const content = render.content.main;
      const mainHeight = mainEl.offsetHeight;
      const contentHeight = content.offsetHeight;

      mainEl.classList.remove(openAbove, openBelow);
      content.classList.remove(openAbove, openBelow);
      mainEl.classList.add(above ? openAbove : openBelow);
      content.classList.add(above ? openAbove : openBelow);

      const inputRect = mainEl.getBoundingClientRect();
      const modalRect = this.modal.getBoundingClientRect();

      content.style.margin = above
        ? "-" + (mainHeight + contentHeight - 1) + "px 0px 0px 0px"
        : "-1px 0px 0px 0px";
      content.style.top =
        inputRect.top + inputRect.height - modalRect.top + "px";
      content.style.left = inputRect.left - modalRect.left + "px";
      content.style.width = inputRect.width + "px";
    };

    render.moveContentAbove = () => place(true);
    render.moveContentBelow = () => place(false);

    this.boundModalReposition = () => {
      if (!this.slimSelect) return;
      if (this.slimSelect.settings.isOpen || this.slimSelect.settings.isFullOpen) {
        this.slimSelect.render.moveContent();
      }
    };
    document.addEventListener("scroll", this.boundModalReposition, true);
  }

  disconnect() {
    this.#cleanupSlimSelect();
  }

  // Server-driven search. SlimSelect calls events.search on each
  // keystroke; we debounce so that rapid typing produces a single
  // request, and abort any in-flight fetch when a newer one starts.
  // Returns a Promise resolving to either a DataArray (rendered as
  // options) or a string (rendered as the no-results label).
  #typeaheadFetch(search, _currentData) {
    if (this._typeaheadDebounce) clearTimeout(this._typeaheadDebounce);
    if (this._typeaheadAbort) this._typeaheadAbort.abort();

    return new Promise((resolve) => {
      this._typeaheadDebounce = setTimeout(() => {
        this._typeaheadAbort = new AbortController();
        this.#performTypeaheadFetch(search, this._typeaheadAbort.signal).then(resolve);
      }, this.typeaheadDebounceMsValue);
    });
  }

  async #performTypeaheadFetch(search, signal) {
    const url = new URL(this.typeaheadUrlValue, window.location.origin);
    url.searchParams.set("q", search || "");

    try {
      const res = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        signal: signal,
      });
      if (!res.ok) return "Search failed";
      const json = await res.json();
      const results = Array.isArray(json.results) ? json.results : [];
      return results.map((row) => ({
        value: String(row.value ?? ""),
        text: String(row.label ?? ""),
      }));
    } catch (e) {
      if (e.name === "AbortError") return [];
      console.warn("[slim-select] typeahead error", e);
      return "Search failed";
    }
  }

  #handleMorph() {
    if (!this.element.isConnected) return;

    // Clean up the old instance without DOM manipulation
    this.#cleanupSlimSelect();

    // Recreate the select - it will automatically pick up the current DOM selections
    this.#setupSlimSelect();
  }

  #cleanupSlimSelect() {
    if (this.boundModalReposition) {
      document.removeEventListener("scroll", this.boundModalReposition, true);
      this.boundModalReposition = null;
    }

    if (this.slimSelect) {
      this.slimSelect.destroy();
      this.slimSelect = null;
    }
  }
}

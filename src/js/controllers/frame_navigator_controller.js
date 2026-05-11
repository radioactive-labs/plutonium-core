import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="frame-navigator"
export default class extends Controller {
  static targets = ["frame", "refreshButton", "backButton", "homeButton", "maximizeLink"];

  connect() {
    this.#loadingStarted()

    this.srcHistory = []
    this.originalFrameSrc = this.frameTarget.src

    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.style.display = ''
      this.refreshButtonClicked = this.refreshButtonClicked.bind(this);
      this.refreshButtonTarget.addEventListener("click", this.refreshButtonClicked);
    }

    if (this.hasBackButtonTarget) {
      this.backButtonClicked = this.backButtonClicked.bind(this);
      this.backButtonTarget.addEventListener("click", this.backButtonClicked);
    }

    if (this.hasHomeButtonTarget) {
      this.homeButtonClicked = this.homeButtonClicked.bind(this);
      this.homeButtonTarget.addEventListener("click", this.homeButtonClicked);
    }

    this.frameLoaded = this.frameLoaded.bind(this);
    this.frameTarget.addEventListener("turbo:frame-load", this.frameLoaded);

    this.frameLoading = this.frameLoading.bind(this);
    this.frameTarget.addEventListener("turbo:click", this.frameLoading);
    this.frameTarget.addEventListener("turbo:submit-start", this.frameLoading);

    this.frameFailed = this.frameFailed.bind(this);
    this.frameTarget.addEventListener("turbo:fetch-request-error", this.frameFailed);
  }

  disconnect() {
    if (this.hasRefreshButtonTarget) this.refreshButtonTarget.removeEventListener("click", this.refreshButtonClicked);
    if (this.hasBackButtonTarget) this.backButtonTarget.removeEventListener("click", this.backButtonClicked);
    if (this.hasHomeButtonTarget) this.homeButtonTarget.removeEventListener("click", this.homeButtonClicked);

    this.frameTarget.removeEventListener("turbo:frame-load", this.frameLoaded);
    this.frameTarget.removeEventListener("turbo:click", this.frameLoading);
    this.frameTarget.removeEventListener("turbo:submit-start", this.frameLoading);
    this.frameTarget.removeEventListener("turbo:fetch-request-error", this.frameFailed);
  }

  frameLoading(event) {
    // turbo:click / turbo:submit-start bubble from links and forms inside
    // the frame, even when those links target a different frame
    // (e.g. data-turbo-frame="remote_modal"). Without this filter, the
    // pulse animation is triggered for navigations that never resolve
    // against this frame, leaving it stuck in a loading state.
    if (event) {
      const trigger = event.target.closest("a, form")
      const requested = trigger?.dataset?.turboFrame
      if (requested && requested !== this.frameTarget.id) return
    }
    this.#loadingStarted()
  }

  frameFailed(event) {
    this.#loadingStopped()
  }

  frameLoaded(event) {
    this.#loadingStopped()

    let src = event.target.src
    this.#notifySrcChanged(src)
  }

  refreshButtonClicked(event) {
    this.frameLoading(null)

    this.frameTarget.reload()
  }

  backButtonClicked(event) {
    this.frameLoading(null)

    this.srcHistory.pop()
    this.frameTarget.src = this.currentSrc
  }

  homeButtonClicked(event) {
    this.frameLoading(null)

    // Clear history immediately so Back/Home vanish during the load.
    this.srcHistory = [this.originalFrameSrc]
    this.#updateNavigationButtonsDisplay()

    // Mark the next frame load as "home" so notifySrcChanged doesn't
    // push the loaded URL onto a fresh stack (the loaded URL may differ
    // from originalFrameSrc due to redirects / trailing slashes).
    this._homeRequested = true

    // Force a reload even if frame.src already matches the original
    // (a same-value assignment wouldn't fire turbo:frame-load).
    this.frameTarget.src = this.originalFrameSrc
    this.frameTarget.reload()
  }

  get currentSrc() { return this.srcHistory[this.srcHistory.length - 1] }

  #notifySrcChanged(src) {
    if (this._homeRequested) {
      // Home click: capture the actually-loaded URL as the new singleton
      // history root (handles redirect/trailing-slash differences from
      // originalFrameSrc).
      this._homeRequested = false
      this.srcHistory = [src]
      this.originalFrameSrc = src
    } else if (src == this.currentSrc) {
      // refresh — do nothing
    } else if (src == this.originalFrameSrc) {
      this.srcHistory = [src]
    } else {
      this.srcHistory.push(src)
    }

    this.#updateNavigationButtonsDisplay()
    if (this.hasMaximizeLinkTarget) this.maximizeLinkTarget.href = src
  }

  #loadingStarted() {
    if (this.hasRefreshButtonTarget) this.refreshButtonTarget.classList.add("motion-safe:animate-spin")
    this.frameTarget.classList.add("motion-safe:animate-pulse")
  }

  #loadingStopped() {
    if (this.hasRefreshButtonTarget) this.refreshButtonTarget.classList.remove("motion-safe:animate-spin")
    this.frameTarget.classList.remove("motion-safe:animate-pulse")
  }

  #updateNavigationButtonsDisplay() {
    if (this.hasHomeButtonTarget) {
      this.homeButtonTarget.style.display = this.srcHistory.length > 2 ? '' : 'none'
    }

    if (this.hasBackButtonTarget) {
      this.backButtonTarget.style.display = this.srcHistory.length > 1 ? '' : 'none'
    }
  }
}

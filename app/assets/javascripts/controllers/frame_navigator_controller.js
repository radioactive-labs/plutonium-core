import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="frame-navigator"
export default class extends Controller {
  static targets = ["frame", "refreshButton", "backButton", "homeButton"];

  connect() {
    console.log(`frame-navigator connected: ${this.element}`)

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
  }

  disconnect() {
    if (this.hasRefreshButtonTarget) this.refreshButtonTarget.removeEventListener("click", this.refreshButtonClicked);
    if (this.hasBackButtonTarget) this.backButtonTarget.removeEventListener("click", this.backButtonClicked);
    if (this.hasHomeButtonTarget) this.homeButtonTarget.removeEventListener("click", this.homeButtonClicked);

    this.frameTarget.removeEventListener("turbo:frame-load", this.frameLoaded);
    this.frameTarget.removeEventListener("turbo:click", this.frameLoading);
    this.frameTarget.removeEventListener("turbo:submit-start", this.frameLoading);
  }

  frameLoading(event) {
    if (this.hasRefreshButtonTarget) this.refreshButtonTarget.classList.add("animate-spin")
  }

  frameLoaded(event) {
    if (this.hasRefreshButtonTarget) this.refreshButtonTarget.classList.remove("animate-spin")

    let src = event.target.src
    if (src == this.currentSrc) {
      // this must be a refresh
      // do nothing
    }
    else if (src == this.originalFrameSrc)
      this.srcHistory = [src]
    else
      this.srcHistory.push(src)

    this.updateNavigationButtonsDisplay()
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

    this.frameTarget.src = this.originalFrameSrc
  }

  private

  get currentSrc() { return this.srcHistory[this.srcHistory.length - 1] }

  updateNavigationButtonsDisplay() {
    if (this.hasHomeButtonTarget) {
      this.homeButtonTarget.style.display = this.srcHistory.length > 1 ? '' : 'none'
    }

    if (this.hasBackButtonTarget) {
      this.backButtonTarget.style.display = this.srcHistory.length > 2 ? '' : 'none'
    }
  }
}

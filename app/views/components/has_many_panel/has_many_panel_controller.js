import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="has-many-panel"
export default class extends Controller {
  static targets = ["frame", "refreshButton", "backButton"];

  connect() {
    console.log(`has-many-panel connected: ${this.element}`)

    this.backButtonTarget.style.display = 'none'
    this.originalFrameSrc = this.frameTarget.src
    this.srcHistory = []

    this.refreshButtonClicked = this.refreshButtonClicked.bind(this);
    this.refreshButtonTarget.addEventListener("click", this.refreshButtonClicked);

    this.backButtonClicked = this.backButtonClicked.bind(this);
    this.backButtonTarget.addEventListener("click", this.backButtonClicked);

    this.frameLoaded = this.frameLoaded.bind(this);
    this.frameTarget.addEventListener("turbo:frame-load", this.frameLoaded);

    this.frameLoading = this.frameLoading.bind(this);
    this.frameTarget.addEventListener("turbo:click", this.frameLoading);
  }

  disconnect() {
    this.refreshButtonTarget.removeEventListener("click", this.refreshButtonClicked);
    this.backButtonTarget.removeEventListener("click", this.backButtonClicked);
    this.frameTarget.removeEventListener("turbo:frame-load", this.frameLoaded);
    this.frameTarget.removeEventListener("turbo:click", this.frameLoading);
  }

  frameLoading(event) {
    this.refreshButtonTarget.classList.add("animate-spin")
  }

  frameLoaded(event) {
    this.refreshButtonTarget.classList.remove("animate-spin")

    let src = event.target.src
    console.log(src, this.currentSrc)
    if (src == this.currentSrc) {
      // this must be a refresh
      // do nothing
    }
    else if (src == this.originalFrameSrc)
      this.srcHistory = [src]
    else
      this.srcHistory.push(src)

    if (this.srcHistory.length > 1) {
      this.backButtonTarget.style.display = ''
    }
    else {
      this.backButtonTarget.style.display = 'none'
    }
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

  get currentSrc() { return this.srcHistory[this.srcHistory.length - 1] }
}

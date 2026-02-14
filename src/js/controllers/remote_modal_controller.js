import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="remote-modal"
export default class extends Controller {
  connect() {
    // Store original scroll position and body overflow
    this.originalScrollPosition = window.scrollY;
    this.originalOverflow = document.body.style.overflow;
    this.bodyStateRestored = false;

    // Lock body scroll
    document.body.style.overflow = "hidden";

    // Show the modal
    this.element.showModal();
    // Add close event listener
    this.element.addEventListener("close", this.handleClose.bind(this));
  }

  close() {
    // Close the modal
    this.element.close();
    this.restoreBodyState();
  }

  disconnect() {
    // Clean up event listener when controller is disconnected
    this.element.removeEventListener("close", this.handleClose);
    this.restoreBodyState();
  }

  handleClose() {
    this.restoreBodyState();
  }

  restoreBodyState() {
    if (this.bodyStateRestored) return;
    this.bodyStateRestored = true;

    // Restore body overflow
    document.body.style.overflow = this.originalOverflow || "";
    // Restore the original scroll position
    window.scrollTo(0, this.originalScrollPosition);
  }
}

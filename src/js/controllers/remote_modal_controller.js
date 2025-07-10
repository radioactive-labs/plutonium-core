import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="remote-modal"
export default class extends Controller {
  connect() {
    // Store original scroll position
    this.originalScrollPosition = window.scrollY;

    // Show the modal
    this.element.showModal();
    // Add close event listener
    this.element.addEventListener("close", this.handleClose.bind(this));
  }

  close() {
    // Close the modal
    this.element.close();
    // Restore the original scroll position
    window.scrollTo(0, this.originalScrollPosition);
  }

  disconnect() {
    // Clean up event listener when controller is disconnected
    this.element.removeEventListener("close", this.handleClose);
  }

  handleClose() {
    // Restore the original scroll position after dialog closes
    window.scrollTo(0, this.originalScrollPosition);
  }
}

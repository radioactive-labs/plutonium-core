import { Controller } from "@hotwired/stimulus"
import getIconByMime from "../support/mime_icon"
import DomElement from "../support/dom_element"

// Connects to data-controller="attachment-preview"
export default class extends Controller {
  static targets = ["thumbnail", "thumbnailLink"]
  static values = {
    mimeType: String,
    thumbnailUrl: String,
  }

  connect() {
    if (!this.hasThumbnailTarget) return;

    if (this.thumbnailUrlValue) {
      this.useThumbnailPreview()
    } else {
      this.useMimeIconPreview()
    }
  }

  remove() {
    this.element.remove()
  }

  useThumbnailPreview() {
    const thumbnail = DomElement.fromTemplate(`
      <img src="${this.thumbnailUrlValue}" class="w-full h-full object-cover rounded-lg" />
    `)

    this.thumbnailLinkTarget.innerHTML = null
    this.thumbnailLinkTarget.appendChild(thumbnail)
  }

  useMimeIconPreview() {
    const mime = getIconByMime(this.mimeTypeValue)

    // Configure the icon
    mime.icon.classList.add(
      'w-3/5',      // 60% width
      'h-4/5',      // 80% height
      'rounded-lg',
      'shadow-lg',
      'bg-white',
      'p-2'         // Add some padding inside the icon container
    )

    // Center the icon in the container
    this.thumbnailLinkTarget.classList.add(
      'flex',
      'items-center',
      'justify-center'
    )

    // Set the background color
    this.thumbnailTarget.style.backgroundColor = mime.color

    // Clear and append the icon
    this.thumbnailLinkTarget.innerHTML = null
    this.thumbnailLinkTarget.appendChild(mime.icon)
  }
}

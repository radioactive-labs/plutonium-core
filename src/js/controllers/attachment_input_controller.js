import { Controller } from "@hotwired/stimulus"

import Uppy from '@uppy/core'
import Dashboard from '@uppy/dashboard'
import ImageEditor from '@uppy/image-editor'
import XHRUpload from '@uppy/xhr-upload'
import DomElement from "../support/dom_element"

// Connects to data-controller="attachment-input"
export default class extends Controller {
  static values = {
    identifier: String,
    endpoint: String,

    maxFileSize: { type: Number, default: null },
    minFileSize: { type: Number, default: null },
    maxTotalSize: { type: Number, default: null },
    maxFileNum: { type: Number, default: null },
    minFileNum: { type: Number, default: null },
    allowedFileTypes: { type: Array, default: null },
    requiredMetaFields: { type: Array, default: [] },
  }

  static outlets = ["attachment-preview", "attachment-preview-container"]

  //======= Lifecycle

  connect() {
    if (this.uppy) return;

    // initialize
    this.uploadedFiles = []

    // hide the input
    this.element.style["display"] = "none"

    // setup uppy
    this.configureUppy()
    // build trigger
    this.#buildTriggers()
    // init state
    this.#onAttachmentsChanged()

    // Just recreate Uppy after morphing - preserve existing attachments
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

  disconnect() {
    this.#cleanupUppy();
  }

  #handleMorph() {
    if (!this.element.isConnected) return;

    // Clean up the old instance
    this.#cleanupUppy();

    // Recreate everything - Uppy, triggers, etc.
    this.uploadedFiles = []
    this.element.style["display"] = "none"
    this.configureUppy()
    this.#buildTriggers()
    this.#onAttachmentsChanged()
  }

  #cleanupUppy() {
    if (this.uppy) {
      this.uppy.destroy();
      this.uppy = null;
    }
    
    // Clean up triggers
    if (this.triggerContainer && this.triggerContainer.parentNode) {
      this.triggerContainer.parentNode.removeChild(this.triggerContainer);
      this.triggerContainer = null;
    }
  }

  attachmentPreviewOutletConnected(outlet, element) {
    this.#onAttachmentsChanged()
  }

  attachmentPreviewOutletDisconnected(outlet, element) {
    this.#onAttachmentsChanged()
  }

  //======= Config

  configureUppy() {
    this.uppy = new Uppy({
      restrictions: {
        maxFileSize: this.maxFileSizeValue,
        minFileSize: this.minFileSizeValue,
        maxTotalFileSize: this.maxTotalSizeValue,
        maxNumberOfFiles: this.maxFileNumValue,
        minNumberOfFiles: this.minFileNumValue,
        allowedFileTypes: this.allowedFileTypesValue,
        requiredMetaFields: this.requiredMetaFieldsValue,
      }
    })
      .use(Dashboard, { inline: false, closeAfterFinish: true })
      .use(ImageEditor, { target: Dashboard })

    this.#configureUploader()
    this.#configureEventHandlers()
  }

  #configureUploader() {
    this.uppy
      .use(XHRUpload, {
        endpoint: this.endpointValue, // path to the upload endpoint
      })
  }

  #configureEventHandlers() {
    this.uppy.on('upload-success', this.#onUploadSuccess.bind(this))
  }

  //======= Events

  #onModalTriggered() {
    // ensure correct color mode is set
    let theme = document.documentElement.getAttribute('data-bs-theme') || 'auto'
    this.#dashboard.setOptions({ theme: theme })

    // clear all successfully uploaded files
    let file = null;
    while (file = this.uploadedFiles.pop()) this.uppy.removeFile(file.id)

    // open modal
    this.#dashboard.openModal()
  }

  #onUploadSuccess(file, response) {
    this.uploadedFiles.push(file)

    // remove current preview
    if (!this.multiple) this.attachmentPreviewOutlets.forEach(a => a.remove())

    // retrieve uploaded file data
    const uploadedFileData = response.body["data"]
    const uploadedFileUrl = response.body["url"]

    // set hidden field value to the uploaded file data so that it's submitted
    // with the form as the attachment
    this.attachmentPreviewContainerOutlet.element.appendChild(
      this.#buildPreview(uploadedFileData, uploadedFileUrl)
    )
  }

  #onAttachmentsChanged() {
    if (!this.deleteAllTrigger) return

    const len = this.attachmentPreviewOutlets.length
    if (len > 1) {
      this.deleteAllTrigger.style["display"] = 'initial'
      this.deleteAllTrigger.textContent = `Delete ${this.attachmentPreviewOutlets.length}`
    } else {
      this.deleteAllTrigger.style["display"] = 'none'
    }
  }

  //======= Builders

  #buildTriggers() {
    this.triggerContainer = document.createElement("div")
    this.triggerContainer.className = "flex items-center gap-2" // Add flex container with alignment
    this.element.insertAdjacentElement('afterend', this.triggerContainer)

    this.#buildUploadTrigger()
    // currently experiencing a weird issue where outlet disconnections are not triggering
    // this.#buildDeleteAllTrigger()

    if (this.uploadTrigger) this.triggerContainer.append(this.uploadTrigger)
    if (this.deleteAllTrigger) this.triggerContainer.append(this.deleteAllTrigger)
  }

  #buildUploadTrigger() {
    const triggerPrompt = this.multiple ? "Choose files" : "Choose file"
    this.uploadTrigger = DomElement.fromTemplate(
      `<button type="button" class="text-gray-900 bg-white border border-gray-300 focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm px-5 py-2.5 dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700 inline-flex items-center">
        <svg class="w-4 h-4 mr-2" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 16">
          <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"/>
        </svg>
        ${triggerPrompt}
      </button>`,
      false
    )
    this.uploadTrigger.addEventListener('click', this.#onModalTriggered.bind(this))
  }

  #buildDeleteAllTrigger() {
    this.deleteAllTrigger = DomElement.fromTemplate(
      `<button type="button" class="text-white bg-red-700 hover:bg-red-800 focus:ring-4 focus:ring-red-300 font-medium rounded-lg text-sm         px-5 py-2.5 dark:bg-red-600 dark:hover:bg-red-700 focus:outline-none dark:focus:ring-red-800 inline-flex items-center">
        Delete ${this.attachmentPreviewOutlets.length}
      </button>`,
      false
    )
    this.deleteAllTrigger.addEventListener('click', () => {
      if (confirm('Are you sure?')) this.attachmentPreviewContainerOutlet.clear()
    })
  }

  #buildPreview(data, url) {
    const filename = data.metadata.filename
    const extension = filename.substring(filename.lastIndexOf('.') + 1, filename.length) || filename
    const multiple = this.multiple ? 'multiple' : ''
    const mimeType = data.metadata.mime_type

    // List of commonly representable mime types
    const representableMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/svg+xml',
      'image/bmp',
      'image/tiff'
    ]

    const isRepresentable = representableMimeTypes.includes(mimeType.toLowerCase())

    // build preview element
    const previewElem = DomElement.fromTemplate(
      this.#buildPreviewTemplate(filename, extension, mimeType, url, isRepresentable)
    )

    // build input element
    const inputElem = DomElement.fromTemplate(
      `<input name="${this.element.name}" ${multiple} type="hidden" autocomplete="off" hidden />`
    )
    inputElem.value = JSON.stringify(data)

    // insert input element into preview
    previewElem.appendChild(inputElem)

    return previewElem
  }

  #buildPreviewTemplate(filename, extension, mimeType, url, isRepresentable) {
    return `
      <div class="${this.identifierValue} attachment-preview group relative bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm hover:shadow-md transition-all duration-300"
           data-controller="attachment-preview"
           data-attachment-preview-mime-type-value="${mimeType}"
           data-attachment-preview-thumbnail-url-value="${isRepresentable ? url : ''}"
           data-attachment-preview-target="thumbnail"
           title="${filename}">
        <a class="block aspect-square overflow-hidden rounded-t-lg"
           data-attachment-preview-target="thumbnailLink">
          ${isRepresentable
        ? `<img src="${url}" class="w-full h-full object-cover" />`
        : `<div class="w-full h-full flex items-center justify-center bg-gray-50 dark:bg-gray-900 text-gray-500 dark:text-gray-400 font-mono">.${extension}</div>`
      }
        </a>
        <div class="px-2 py-1.5 text-sm text-gray-700 dark:text-gray-300 border-t border-gray-200 dark:border-gray-700 truncate text-center bg-white dark:bg-gray-800"
             title="${filename}">
          ${filename}
        </div>
        <button type="button"
                class="w-full py-2 px-4 text-sm text-red-600 dark:text-red-400 bg-white dark:bg-gray-800 hover:bg-red-50 dark:hover:bg-red-900/50 rounded-b-lg transition-colors duration-200 flex items-center justify-center gap-2 border-t border-gray-200 dark:border-gray-700"
                data-action="click->attachment-preview#remove">
          <span class="bi bi-trash"></span>
          Delete
        </button>
      </div>
    `
  }

  //======= Getters

  get #dashboard() { return this.uppy.getPlugin('Dashboard') }

  get multiple() { return this.maxFileNumValue != 1 }
}

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
    // initialize
    this.uploadedFiles = []

    // hide the input
    this.element.style["display"] = "none"

    // setup uppy
    this.configureUppy()

    // build trigger
    this.buildTriggers()
  }

  disconnect() {
    this.uppy = null
  }

  attachmentPreviewOutletConnected(outlet, element) {
    this.onAttachmentsChanged()
  }

  attachmentPreviewOutletDisconnected(outlet, element) {
    this.onAttachmentsChanged()
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

    this.configureUploader()
    this.configureEventHandlers()
  }

  configureUploader() {
    this.uppy
      .use(XHRUpload, {
        endpoint: '/upload', // path to the upload endpoint
      })
  }

  configureEventHandlers() {
    this.uppy.on('upload-success', this.onUploadSuccess.bind(this))
  }

  //======= Events

  onModalTriggered() {
    // ensure correct color mode is set
    let theme = document.documentElement.getAttribute('data-bs-theme') || 'auto'
    this.dashboard.setOptions({ theme: theme })

    // clear all successfully uploaded files
    let file = null;
    while (file = this.uploadedFiles.pop()) this.uppy.removeFile(file.id)

    // open modal
    this.dashboard.openModal()
  }

  onUploadSuccess(file, response) {
    this.uploadedFiles.push(file)

    // remove current preview
    if (!this.multiple) this.attachmentPreviewOutlets.forEach(a => a.remove())

    // retrieve uploaded file data
    const uploadedFileData = response.body["data"]
    const uploadedFileUrl = response.body["url"]

    // set hidden field value to the uploaded file data so that it's submitted
    // with the form as the attachment
    this.attachmentPreviewContainerOutlet.element.appendChild(
      this.buildPreview(uploadedFileData, uploadedFileUrl)
    )
  }

  onAttachmentsChanged() {
    if (!this.deleteAllTrigger) return;

    const len = this.attachmentPreviewOutlets.length
    if (len > 1) {
      this.deleteAllTrigger.style["display"] = 'initial'
      this.deleteAllTrigger.textContent = `Delete ${this.attachmentPreviewOutlets.length}`
    }
    else {
      this.deleteAllTrigger.style["display"] = 'none'
    }
  }

  //======= Builders

  buildTriggers() {
    this.triggerContainer = document.createElement("div")
    this.triggerContainer.classList.add("mb-2")
    this.element.insertAdjacentElement('afterend', this.triggerContainer)

    this.buildUploadTrigger()
    this.buildDeleteAllTrigger()

    if (this.uploadTrigger) this.triggerContainer.append(this.uploadTrigger)
    if (this.deleteAllTrigger) this.triggerContainer.append(this.deleteAllTrigger)
  }

  buildUploadTrigger() {
    const triggerPrompt = this.multiple ? "Choose files" : "Choose file"
    this.uploadTrigger = DomElement.fromTemplate(
      `<button type="button" class="attachment-input-trigger btn btn-outline-secondary">${triggerPrompt}</button>`,
      false
    )
    this.uploadTrigger.addEventListener('click', this.onModalTriggered.bind(this))

  }


  buildDeleteAllTrigger() {
    this.deleteAllTrigger = DomElement.fromTemplate(
      `<button type="button" class="attachment-input-trigger btn btn-outline-danger mx-1">Delete ${this.attachmentPreviewOutlets.length}</button>`,
      false
    )
    this.deleteAllTrigger.addEventListener('click', () => {
      if (confirm('Are you sure?')) this.attachmentPreviewContainerOutlet.clear()
    })
    this.onAttachmentsChanged()
  }

  buildPreview(data, url) {
    const filename = data.metadata.filename
    const extension = filename.substring(filename.lastIndexOf('.') + 1, filename.length) || filename
    const multiple = this.multiple ? 'multiple' : ''
    const mimeType = data.metadata.mime_type

    // build preview element
    const previewElem = DomElement.fromTemplate(this.buildPreviewTemplate(filename, extension, mimeType, url))

    // build input element
    const inputElem = DomElement.fromTemplate(`<input name="${this.element.name}" ${multiple} type="hidden" />`)
    inputElem.value = JSON.stringify(data);

    // insert input element into preview
    previewElem.appendChild(inputElem)

    return previewElem
  }

  buildPreviewTemplate(filename, extension, mimeType, url) {
    // Any changes made here must be reflected in attachment_helper#attachment_preview_thumnail

    const thumbnailUrl = /image\/*/.test(mimeType) ? url : null;
    return `
      <div class="${this.identifierValue} attachment-preview d-inline-block text-center" title="${filename}"
            data-controller="attachment-preview" data-attachment-preview-mime-type-value="${mimeType}"
            data-attachment-preview-thumbnail-url-value="${thumbnailUrl}">
          <figure class="figure my-1" style="width: 160px;">
              <div class="d-inline-block img-thumbnail" data-attachment-preview-target="thumbnail">
                <a class="d-block text-decoration-none user-select-none fs-5 font-monospace text-body-secondary"
                    style="width:150px; height:150px; line-height: 150px;" target="blank"
                    href="${url}"
                    data-attachment-preview-target="thumbnailLink">${extension}</a>
              </div>
              <figcaption class="figure-caption text-truncate">
                  <a class="text-decoration-none" target="blank" href="${url}">${filename}</a>
                  <p class="text-danger m-0" role="button" data-action="click->attachment-preview#remove">
                    <span class="bi bi-trash"> Delete</span>
                  </p>
              </figcaption>
          </figure>
      </div>
  `}

  //======= Getters

  get dashboard() { return this.uppy.getPlugin('Dashboard') }

  get multiple() { return this.maxFileNumValue != 1 }

}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form"
export default class extends Controller {
  connect() {
  }
 
  preSubmit() {
    // Some widgets (e.g. slim-select) dispatch their own change event on top
    // of the native one, so this can fire twice per user action. Remove any
    // prior hidden field before appending a fresh one to avoid duplicates.
    this.element.querySelectorAll('input[name="pre_submit"]').forEach(n => n.remove());

    const hiddenField = document.createElement('input');
    hiddenField.type = 'hidden';
    hiddenField.name = 'pre_submit';
    hiddenField.value = 'true';
    this.element.appendChild(hiddenField);

    // Skip validation by setting novalidate attribute
    this.element.setAttribute('novalidate', '');

    this.submit();
  }
 
  submit() {
    this.element.requestSubmit()
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form"
export default class extends Controller {
  connect() {
  }
 
  preSubmit() {
    // Create a hidden input field
    const hiddenField = document.createElement('input');
    hiddenField.type = 'hidden';
    hiddenField.name = 'pre_submit';
    hiddenField.value = 'true';
 
    // Append it to the form
    this.element.appendChild(hiddenField);

    // Skip validation by setting novalidate attribute
    this.element.setAttribute('novalidate', '');

    // Submit the form
    this.submit();
  }
 
  submit() {
    this.element.requestSubmit()
  }
}

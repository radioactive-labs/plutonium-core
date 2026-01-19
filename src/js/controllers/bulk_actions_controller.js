import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-actions"
// Manages bulk action selection in resource tables
export default class extends Controller {
  static targets = ["checkbox", "checkboxAll", "toolbar", "selectedCount", "actionButton", "selectionCell"]
  static values = {
    hasActions: { type: Boolean, default: false }
  }

  connect() {
    // Show selection column only if bulk actions exist
    if (this.hasActionsValue) {
      this.enableSelection()
    }
  }

  enableSelection() {
    // Show all selection cells (header + body cells)
    this.selectionCellTargets.forEach(el => el.classList.remove("hidden"))
  }

  toggle() {
    this.updateUI()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    this.updateUI()
  }

  updateUI() {
    const checked = this.checked
    const total = this.checkboxTargets.length

    // Update "select all" checkbox state (checked, unchecked, or indeterminate)
    if (this.hasCheckboxAllTarget) {
      this.checkboxAllTarget.checked = checked.length === total && total > 0
      this.checkboxAllTarget.indeterminate = checked.length > 0 && checked.length < total
    }

    // Show toolbar only when items are selected
    if (this.hasToolbarTarget) {
      this.toolbarTarget.classList.toggle("hidden", checked.length === 0)
    }

    // Update selected count display
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = checked.length
    }

    // Update action button URLs and visibility based on allowed actions
    this.updateActionButtons()
  }

  updateActionButtons() {
    const checked = this.checked
    const ids = checked.map(cb => cb.value)
    const idsParam = ids.map(id => `ids[]=${encodeURIComponent(id)}`).join("&")

    // Compute intersection of allowed actions across all selected records
    const allowedActions = this.computeAllowedActions(checked)

    this.actionButtonTargets.forEach(button => {
      const baseUrl = button.dataset.bulkActionUrl
      const actionName = button.dataset.bulkActionName

      // Update URL with selected IDs
      if (baseUrl) {
        button.href = idsParam ? `${baseUrl}?${idsParam}` : baseUrl
      }

      // Show/hide button based on whether action is allowed for all selected records
      button.style.display = allowedActions.has(actionName) ? '' : 'none'
    })
  }

  // Compute the intersection of allowed actions across all selected checkboxes
  computeAllowedActions(checked) {
    if (checked.length === 0) {
      return new Set()
    }

    // Start with actions allowed for the first selected record
    let intersection = new Set(this.getAllowedActionsForCheckbox(checked[0]))

    // Intersect with actions allowed for each subsequent record
    for (let i = 1; i < checked.length; i++) {
      const actions = this.getAllowedActionsForCheckbox(checked[i])
      intersection = new Set([...intersection].filter(a => actions.includes(a)))
    }

    return intersection
  }

  getAllowedActionsForCheckbox(checkbox) {
    const allowedActions = checkbox.dataset.allowedActions
    return allowedActions ? allowedActions.split(",").filter(a => a) : []
  }

  get checked() {
    return this.checkboxTargets.filter(cb => cb.checked)
  }

  get unchecked() {
    return this.checkboxTargets.filter(cb => !cb.checked)
  }
}

import { Controller } from "@hotwired/stimulus"

// Select-all helpers for the RBAC permission grid
// (Plutonium::UI::Form::Components::RbacPermissions). Each group's legend
// checkbox mirrors its permissions (indeterminate when partly checked), and
// the action buttons toggle one action (read, create, ...) across every group.
export default class extends Controller {
  static targets = ["group", "groupToggle", "permission"]

  connect() {
    this.sync()
  }

  toggleGroup(event) {
    const group = event.target.closest("[data-rbac-permissions-target='group']")
    this.permissionsIn(group).forEach((box) => { box.checked = event.target.checked })
    this.sync()
  }

  toggleAction({ params: { permissionAction } }) {
    const boxes = this.permissionTargets.filter((box) => box.dataset.permissionAction === permissionAction)
    const check = !boxes.every((box) => box.checked)
    boxes.forEach((box) => { box.checked = check })
    this.sync()
  }

  sync() {
    this.groupTargets.forEach((group) => {
      const boxes = this.permissionsIn(group)
      const toggle = group.querySelector("[data-rbac-permissions-target='groupToggle']")
      const checked = boxes.filter((box) => box.checked).length
      toggle.checked = boxes.length > 0 && checked === boxes.length
      toggle.indeterminate = checked > 0 && checked < boxes.length
    })
  }

  permissionsIn(group) {
    return [...group.querySelectorAll("[data-rbac-permissions-target='permission']")]
  }
}

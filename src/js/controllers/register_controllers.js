// Import controllers here
import ResourceHeaderController from "./resource_header_controller.js"
import NestedResourceFormFieldsController from "./nested_resource_form_fields_controller.js"
import FormController from "./form_controller.js"
import ResourceDropDownController from "./resource_drop_down_controller.js"
import ResourceCollapseController from "./resource_collapse_controller.js"
import ResourceDismissController from "./resource_dismiss_controller.js"
import FrameNavigatorController from "./frame_navigator_controller.js"
import ColorModeController from "./color_mode_controller.js"
import EasyMDEController from "./easymde_controller.js"
import SlimSelectController from "./slim_select_controller.js"
import FlatpickrController from "./flatpickr_controller.js"
import IntlTelInputController from "./intl_tel_input_controller.js"
import SelectNavigatorController from "./select_navigator.js"
import ResourceTabListController from "./resource_tab_list_controller.js"
import AttachmentInputController from "./attachment_input_controller.js"
import AttachmentPreviewController from "./attachment_preview_controller.js"
import AttachmentPreviewContainerController from "./attachment_preview_container_controller.js"
import SidebarController from "./sidebar_controller.js"
import PasswordVisibilityController from "./password_visibility_controller.js"

export default function (application) {
  // Register controllers here
  application.register("password-visibility", PasswordVisibilityController)
  application.register("sidebar", SidebarController)
  application.register("resource-header", ResourceHeaderController)
  application.register("nested-resource-form-fields", NestedResourceFormFieldsController)
  application.register("form", FormController)
  application.register("resource-drop-down", ResourceDropDownController)
  application.register("resource-collapse", ResourceCollapseController)
  application.register("resource-dismiss", ResourceDismissController)
  application.register("frame-navigator", FrameNavigatorController)
  application.register("color-mode", ColorModeController)
  application.register("easymde", EasyMDEController)
  application.register("slim-select", SlimSelectController)
  application.register("flatpickr", FlatpickrController)
  application.register("intl-tel-input", IntlTelInputController)
  application.register("select-navigator", SelectNavigatorController)
  application.register("resource-tab-list", ResourceTabListController)
  application.register("attachment-input", AttachmentInputController)
  application.register("attachment-preview", AttachmentPreviewController)
  application.register("attachment-preview-container", AttachmentPreviewContainerController)
}

// Import controllers here
import HeaderController from "./header_controller.js"
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

export default function (application) {
  // Register controllers here
  application.register("header", HeaderController)
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
}

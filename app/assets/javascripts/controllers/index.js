// Import controllers here
import HasManyPanelController from "../../../../app/views/components/has_many_panel/has_many_panel_controller.js"
import NestedResourceFormFieldsController from "../../../../app/views/components/nested_resource_form_fields/nested_resource_form_fields_controller.js"
import TabBarController from "../../../../app/views/components/tab_bar/tab_bar_controller.js"
import ToolbarController from "../../../../app/views/components/toolbar/toolbar_controller.js"
import TableSearchInputController from "../../../../app/views/components/table_search_input/table_search_input_controller.js"
import TableToolbarController from "../../../../app/views/components/table_toolbar/table_toolbar_controller.js"
import TableController from "../../../../app/views/components/table/table_controller.js"
import FormController from "../../../../app/views/components/form/form_controller.js"
import ResourceDropDownController from "./resource_drop_down_controller.js"
import ResourceDismissController from "./resource_dismiss_controller.js"
import FrameNavigatorController from "./frame_navigator_controller.js"

export function registerControllers(application) {
  // Register controllers here
  application.register("has-many-panel", HasManyPanelController)
  application.register("nested-resource-form-fields", NestedResourceFormFieldsController)
  application.register("tab-bar", TabBarController)
  application.register("toolbar", ToolbarController)
  application.register("table-search-input", TableSearchInputController)
  application.register("table-toolbar", TableToolbarController)
  application.register("table", TableController)
  application.register("form", FormController)
  application.register("resource-drop-down", ResourceDropDownController)
  application.register("resource-dismiss", ResourceDismissController)
  application.register("frame-navigator", FrameNavigatorController)

}

// Export controllers here
export { HasManyPanelController }
export { NestedResourceFormFieldsController };
export { TabBarController };
export { ToolbarController };
export { TableSearchInputController };
export { TableToolbarController };
export { TableController };
export { FormController };
export { ResourceDropDownController };
export { ResourceDismissController };
export { FrameNavigatorController };

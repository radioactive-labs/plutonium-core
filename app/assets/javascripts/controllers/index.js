// Import controllers here
import SidebarMenuItemController from "../../../../app/views/components/sidebar_menu_item/sidebar_menu_item_controller.js"
import SidebarMenuController from "../../../../app/views/components/sidebar_menu/sidebar_menu_controller.js"
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
import ColorModeController from "./color_mode.js"

export function registerControllers(application) {
  // Register controllers here
  application.register("sidebar-menu-item", SidebarMenuItemController)
  application.register("sidebar-menu", SidebarMenuController)
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
  application.register("color-mode", ColorModeController)

}

// Export controllers here
export { SidebarMenuItemController }
export { SidebarMenuController }
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
export { ColorModeController };

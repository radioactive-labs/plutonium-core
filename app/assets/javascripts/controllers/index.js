// Import controllers here
import ResourceLayoutController from "../../../../app/views/components/resource_layout/resource_layout_controller.js"
import NavGridMenuItemController from "../../../../app/views/components/nav_grid_menu_item/nav_grid_menu_item_controller.js"
import NavGridMenuController from "../../../../app/views/components/nav_grid_menu/nav_grid_menu_controller.js"
import NavUserSectionController from "../../../../app/views/components/nav_user_section/nav_user_section_controller.js"
import NavUserLinkController from "../../../../app/views/components/nav_user_link/nav_user_link_controller.js"
import NavUserController from "../../../../app/views/components/nav_user/nav_user_controller.js"
import ResourceHeaderController from "../../../../app/views/components/resource_header/resource_header_controller.js"
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
  application.register("resource-layout", ResourceLayoutController)
  application.register("nav-grid-menu-item", NavGridMenuItemController)
  application.register("nav-grid-menu", NavGridMenuController)
  application.register("nav-user-section", NavUserSectionController)
  application.register("nav-user-link", NavUserLinkController)
  application.register("nav-user", NavUserController)
  application.register("resource-header", ResourceHeaderController)
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
export { ResourceLayoutController }
export { NavGridMenuItemController }
export { NavGridMenuController }
export { NavUserSectionController }
export { NavUserLinkController }
export { NavUserController }
export { ResourceHeaderController }
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

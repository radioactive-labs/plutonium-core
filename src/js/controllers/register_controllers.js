// Import controllers here
import ResourceLayoutController from "./resource_layout_controller.js"
import NavGridMenuItemController from "./nav_grid_menu_item_controller.js"
import NavGridMenuController from "./nav_grid_menu_controller.js"
import NavUserSectionController from "./nav_user_section_controller.js"
import NavUserLinkController from "./nav_user_link_controller.js"
import NavUserController from "./nav_user_controller.js"
import HeaderController from "./header_controller.js"
import SidebarMenuItemController from "./sidebar_menu_item_controller.js"
import SidebarMenuController from "./sidebar_menu_controller.js"
import SidebarController from "./sidebar_controller.js"
import HasManyPanelController from "./has_many_panel_controller.js"
import NestedResourceFormFieldsController from "./nested_resource_form_fields_controller.js"
import ToolbarController from "./toolbar_controller.js"
import TableSearchInputController from "./table_search_input_controller.js"
import TableToolbarController from "./table_toolbar_controller.js"
import TableController from "./table_controller.js"
import FormController from "./form_controller.js"
import ResourceDropDownController from "./resource_drop_down_controller.js"
import ResourceCollapseController from "./resource_collapse_controller.js"
import ResourceDismissController from "./resource_dismiss_controller.js"
import FrameNavigatorController from "./frame_navigator_controller.js"
import ColorModeController from "./color_mode_controller.js"
import EasyMDEController from "./easymde_controller.js"
import SlimSelectController from "./slim_select_controller.js"
import FlatpickrController from "./flatpickr_controller.js"

export default function (application) {
  // Register controllers here
  application.register("resource-layout", ResourceLayoutController)
  application.register("nav-grid-menu-item", NavGridMenuItemController)
  application.register("nav-grid-menu", NavGridMenuController)
  application.register("nav-user-section", NavUserSectionController)
  application.register("nav-user-link", NavUserLinkController)
  application.register("nav-user", NavUserController)
  application.register("header", HeaderController)
  application.register("sidebar-menu-item", SidebarMenuItemController)
  application.register("sidebar-menu", SidebarMenuController)
  application.register("sidebar", SidebarController)
  application.register("has-many-panel", HasManyPanelController)
  application.register("nested-resource-form-fields", NestedResourceFormFieldsController)
  application.register("toolbar", ToolbarController)
  application.register("table-search-input", TableSearchInputController)
  application.register("table-toolbar", TableToolbarController)
  application.register("table", TableController)
  application.register("form", FormController)
  application.register("resource-drop-down", ResourceDropDownController)
  application.register("resource-collapse", ResourceCollapseController)
  application.register("resource-dismiss", ResourceDismissController)
  application.register("frame-navigator", FrameNavigatorController)
  application.register("color-mode", ColorModeController)
  application.register("easymde", EasyMDEController)
  application.register("slim-select", SlimSelectController)
  application.register("flatpickr", FlatpickrController)
}

import { application } from "./application"

// Register controllers here

import ToolbarController from "../../../../app/views/components/toolbar/toolbar_controller.js"
application.register("toolbar", ToolbarController)

import TableSearchInputController from "../../../../app/views/components/table_search_input/table_search_input_controller.js"
application.register("table-search-input", TableSearchInputController)

import TableToolbarController from "../../../../app/views/components/table_toolbar/table_toolbar_controller.js"
application.register("table-toolbar", TableToolbarController)

import TableController from "../../../../app/views/components/table/table_controller.js"
application.register("table", TableController)

import FormController from "../../../../app/views/components/form/form_controller.js"
application.register("form", FormController)

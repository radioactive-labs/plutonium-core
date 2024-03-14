import { application } from "./application"

// Register controllers here

import ToolbarController from "../../../views/components/toolbar/toolbar_component.js"
application.register("toolbar", ToolbarController)

import TableSearchInputController from "../../../views/components/table_search_input/table_search_input_component.js"
application.register("table_search_input", TableSearchInputController)

import TableToolbarController from "../../../views/components/table_toolbar/table_toolbar_component.js"
application.register("table_toolbar", TableToolbarController)

import TableController from "../../../views/components/table/table_component.js"
application.register("table", TableController)

import FormController from "../../../views/components/form/form_component.js"
application.register("form", FormController)

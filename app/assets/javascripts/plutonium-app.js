import { Application } from "@hotwired/stimulus"
const application = Application.start()

import { registerControllers } from "./plutonium"
registerControllers(application)

import "./turbo"

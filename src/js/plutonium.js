import "@hotwired/turbo"

import { Application } from "@hotwired/stimulus"
const application = Application.start()

import { registerControllers } from "./core"
registerControllers(application)

import "./turbo"

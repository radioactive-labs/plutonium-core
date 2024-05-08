import { Application } from "@hotwired/stimulus"
import "mapkick/bundle"

const application = Application.start()
window.Stimulus = application

export { application }

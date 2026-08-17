# The run resource, registered with `controller: "interaction_runs"` so that the
# class-name-derived path ("plutonium/interaction/runs") does not introduce an
# `AdminPortal::Plutonium` namespace — which would shadow the gem's ::Plutonium
# for every constant this package resolves.
#
# Because the controller is no longer named after its resource, it has to say
# what it serves.
class AdminPortal::InteractionRunsController < ::AdminPortal::ResourceController
  controller_for ::Plutonium::Interaction::Run
end

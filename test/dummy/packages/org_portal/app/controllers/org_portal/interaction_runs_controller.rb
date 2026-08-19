class OrgPortal::InteractionRunsController < ::OrgPortal::ResourceController
  # The controller's name doesn't match Run's real, namespaced class
  # (Plutonium::Interaction::Run), so inference can't find it on its own.
  controller_for ::Plutonium::Interaction::Run

  include OrgPortal::Concerns::Controller
end

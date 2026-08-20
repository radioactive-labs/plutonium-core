class OrgPortal::AsyncRunsController < ::OrgPortal::ResourceController
  # The controller's name doesn't match Run's real, namespaced class
  # (Plutonium::Interaction::Async::Run), so inference can't find it on its own.
  controller_for ::Plutonium::Interaction::Async::Run

  include OrgPortal::Concerns::Controller
end

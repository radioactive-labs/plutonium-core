class AdminPortal::AsyncRunsController < ::AdminPortal::ResourceController
  # The controller's name doesn't match Run's real, namespaced class
  # (Plutonium::Interaction::AsyncRun), so inference can't find it on its own.
  controller_for ::Plutonium::Interaction::AsyncRun

  include AdminPortal::Concerns::Controller
end

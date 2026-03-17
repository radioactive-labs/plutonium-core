module OrgPortal
  # Base controller for non-resource pages (dashboard, settings, etc.).
  class PlutoniumController < ::PlutoniumController
    include OrgPortal::Concerns::Controller
  end
end

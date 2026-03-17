module LocusPortal
  # Base controller for non-resource pages (dashboard, settings, etc.).
  class PlutoniumController < ::PlutoniumController
    include LocusPortal::Concerns::Controller
  end
end

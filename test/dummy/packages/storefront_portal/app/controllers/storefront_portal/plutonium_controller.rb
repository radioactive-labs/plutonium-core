module StorefrontPortal
  # Base controller for non-resource pages (dashboard, settings, etc.).
  class PlutoniumController < ::PlutoniumController
    include StorefrontPortal::Concerns::Controller
  end
end

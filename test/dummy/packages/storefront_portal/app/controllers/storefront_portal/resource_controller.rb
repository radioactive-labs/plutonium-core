module StorefrontPortal
  # Base controller for portal resources when no feature package controller exists.
  # Add customizations to Concerns::Controller, not here.
  class ResourceController < ::ResourceController
    include StorefrontPortal::Concerns::Controller
  end
end

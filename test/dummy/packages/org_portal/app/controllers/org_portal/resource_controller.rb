module OrgPortal
  # Base controller for portal resources when no feature package controller exists.
  # Add customizations to Concerns::Controller, not here.
  class ResourceController < ::ResourceController
    include OrgPortal::Concerns::Controller
  end
end

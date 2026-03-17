module LocusPortal
  # Base controller for portal resources when no feature package controller exists.
  # Add customizations to Concerns::Controller, not here.
  class ResourceController < ::ResourceController
    include LocusPortal::Concerns::Controller
  end
end

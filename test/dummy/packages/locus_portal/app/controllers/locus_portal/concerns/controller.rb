module LocusPortal
  module Concerns
    # Portal-wide controller customizations go here.
    # Included by both ResourceController and PlutoniumController.
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:user)
      # add concerns above.
    end
  end
end

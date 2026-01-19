module AuthorPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:user)
      # add concerns above.
    end
  end
end

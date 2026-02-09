module TestPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller

      # add concerns above.

      included do
        helper_method :current_user
      end

      def current_user
        raise NotImplementedError, "#{self.class}#current_user must return a non nil value"
      end
    end
  end
end

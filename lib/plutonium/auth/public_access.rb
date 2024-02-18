module Plutonium
  module Auth
    module PublicAccess
      extend ActiveSupport::Concern

      included do
        helper_method :current_user
      end

      private

      def current_user
        "Guest"
      end
    end
  end
end

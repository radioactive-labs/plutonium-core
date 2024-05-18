module Plutonium
  module Rodauth
    module ControllerMethods
      extend ActiveSupport::Concern

      included do
        layout "rodauth"
        append_view_path File.expand_path("app/views", Plutonium.root)
        helper_method :application_name
      end

      private

      def application_name
        Plutonium.application_name
      end
    end
  end
end

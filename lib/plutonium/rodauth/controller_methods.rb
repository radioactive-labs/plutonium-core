module Plutonium
  module Rodauth
    module ControllerMethods
      extend ActiveSupport::Concern

      included do
        layout "rodauth"
        append_view_path File.expand_path("app/views", Plutonium.root)
      end
    end
  end
end

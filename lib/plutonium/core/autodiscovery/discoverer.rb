module Plutonium
  module Core
    module Autodiscovery
      module Discoverer
        extend ActiveSupport::Concern

        private

        def resource_class
          raise NotImplementedError, "#{self.class}#resource_class"
        end
      end
    end
  end
end

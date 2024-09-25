module Plutonium
  module Definition
    module Sorting
      extend ActiveSupport::Concern

      included do
        defineable_props :sort

        def self.sorts(*names)
          names.each { |name| sort name }
        end
      end
    end
  end
end

require "pundit"

module Plutonium
  module Policy
    module Scope
      def self.included(base)
        base.include Plutonium::Policy::Initializer
      end
    end
  end
end

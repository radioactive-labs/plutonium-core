module Plutonium
  module Definition
    module Scoping
      extend ActiveSupport::Concern

      included do
        class_attribute :_default_scope, instance_writer: false, instance_predicate: false

        def self.default_scope(name = nil)
          self._default_scope = name.to_sym if name
          _default_scope
        end
      end

      def default_scope
        self.class._default_scope
      end
    end
  end
end

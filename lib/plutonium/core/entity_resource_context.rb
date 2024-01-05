module Plutonium
  module Core
    class EntityResourceContext < ResourceContext
      attr_reader :entity

      def initialize(entity:, **kwargs)
        @entity = entity
        super(**kwargs)
      end

      def parent
        @parent || @entity
      end
    end
  end
end

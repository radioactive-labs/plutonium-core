module Plutonium
  module Policy
    module EntityResourcePolicy
      def show?
        read? && @record.entity.id == context.entity.id
      end

      def edit?
        @record.entity.id == context.entity.id
      end

      def permitted_attributes_for_read
        super - %i[entity]
      end

      def permitted_attributes_for_create
        super - %i[entity_id]
      end

      private

      def authorize!(context)
        super
        raise Pundit::NotAuthorizedError, "requires an entity" unless context.entity
      end
    end
  end
end

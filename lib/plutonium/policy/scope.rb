require "pundit"

module Plutonium
  module Policy
    class Scope
      include Plutonium::Policy::Initializer

      def resolve
        scope = context.resource_context.resource_class.all
        if @context.resource_context.parent.present?
          scope = scope.associated_with(@context.resource_context.parent)
        elsif @context.resource_context.scope.present?
          scope = scope.associated_with(@context.resource_context.scope)
        end
        scope
      end
    end
  end
end

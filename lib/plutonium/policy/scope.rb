require "pundit"

module Plutonium
  module Policy
    class Scope
      include Plutonium::Policy::Initializer

      def resolve
        scope = context.resource_class.all
        if @context.parent.present?
          scope = scope.associated_with(@context.parent)
        elsif @context.scope.present?
          scope = scope.associated_with(@context.scope)
        end
        scope
      end
    end
  end
end

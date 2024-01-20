require "pundit"

module Plutonium
  module Policy
    class Scope
      include Plutonium::Policy::Initializer

      def resolve
        scope = context.resource_class.all
        if @context.parent.present?
          scope = scope.for_parent(@context.parent)
        elsif @context.scope.present?
          scope = scope.where(@context.scope.attribute => @context.scope.record)
        end
        scope
      end
    end
  end
end

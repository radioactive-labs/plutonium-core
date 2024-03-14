module Plutonium
  module Helpers
    module ComponentHelper
      def resolve_component(name)
        Plutonium::ComponentRegistry.resolve name
      end

      def render_component(name, *, **, &block)
        component = resolve_component name
        render(component.new(*, **), &block)
      end
    end
  end
end

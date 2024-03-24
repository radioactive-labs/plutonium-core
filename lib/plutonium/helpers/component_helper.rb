module Plutonium
  module Helpers
    module ComponentHelper
      def resolve_component(name)
        Plutonium::ComponentRegistry.resolve name
      end

      def render_component(name, *, **, &)
        component = resolve_component name
        render(component.new(*, **), &)
      end
    end
  end
end

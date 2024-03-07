module Plutonium
  module Helpers
    module ComponentHelper
      def resource_component(name, *, **, &block)
        component = Plutonium::ComponentRegistry.resolve name
        render(component.new(*, **), &block)
      end
    end
  end
end

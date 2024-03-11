module Plutonium::UI
  class ToolbarComponent < Plutonium::UI::Base
    option :resource_class
    option :parent, optional: true
    option :resource, optional: true
  end
end

Plutonium::ComponentRegistry.register :toolbar, to: Plutonium::UI::ToolbarComponent

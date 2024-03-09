module Plutonium::UI
  class Breadcrumbs < Plutonium::UI::Base
    option :resource_class
    option :parent, optional: true
    option :resource, optional: true
  end
end

Plutonium::ComponentRegistry.register :breadcrumbs, to: Plutonium::UI::Breadcrumbs

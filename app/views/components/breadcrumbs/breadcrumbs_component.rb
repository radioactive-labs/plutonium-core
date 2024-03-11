module Plutonium::UI
  class BreadcrumbsComponent < Plutonium::UI::Base
    option :resource_class
    option :parent, optional: true
    option :resource, optional: true
  end
end

Plutonium::ComponentRegistry.register :breadcrumbs, to: Plutonium::UI::BreadcrumbsComponent

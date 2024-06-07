module PlutoniumUi
  class BreadcrumbsComponent < PlutoniumUi::Base
    option :resource_class
    option :parent, optional: true
    option :resource, optional: true
  end
end

Plutonium::ComponentRegistry.register :breadcrumbs, to: PlutoniumUi::BreadcrumbsComponent

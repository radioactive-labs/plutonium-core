module Plutonium::Ui
  class BreadcrumbsComponent < Plutonium::Ui::Base
    option :resource_class
    option :parent, optional: true
    option :resource, optional: true
  end
end

Plutonium::ComponentRegistry.register :breadcrumbs, to: Plutonium::Ui::BreadcrumbsComponent

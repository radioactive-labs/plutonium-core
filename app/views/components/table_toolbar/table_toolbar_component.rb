module Plutonium::UI
  class TableToolbarComponent < Plutonium::UI::Base
    option :resource_class
    option :search_object
    option :actions
  end
end

Plutonium::ComponentRegistry.register :table_toolbar, to: Plutonium::UI::TableToolbarComponent

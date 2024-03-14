module Plutonium::UI
  class TableToolbarComponent < Plutonium::UI::Base
    option :resource_class
    option :search_object
    option :actions

    def classname
      "flex flex-col md:flex-row items-center justify-between space-y-3 md:space-y-0 md:space-x-4 p-4 #{super}"
    end
  end
end

Plutonium::ComponentRegistry.register :table_toolbar, to: Plutonium::UI::TableToolbarComponent

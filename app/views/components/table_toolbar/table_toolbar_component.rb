module Plutonium::Ui
  class TableToolbarComponent < Plutonium::Ui::Base
    option :resource_class
    option :search_object
    option :actions

    private

    def base_attributes
      {
        controller: "table-toolbar"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :table_toolbar, to: Plutonium::Ui::TableToolbarComponent

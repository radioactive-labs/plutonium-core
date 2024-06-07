module PlutoniumUi
  class TableToolbarComponent < PlutoniumUi::Base
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

Plutonium::ComponentRegistry.register :table_toolbar, to: PlutoniumUi::TableToolbarComponent

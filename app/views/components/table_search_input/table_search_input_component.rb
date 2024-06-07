module PlutoniumUi
  class TableSearchInputComponent < PlutoniumUi::Base
    option :search_object

    private

    def base_attributes
      {
        controller: "table-search-input"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :table_search_input, to: PlutoniumUi::TableSearchInputComponent

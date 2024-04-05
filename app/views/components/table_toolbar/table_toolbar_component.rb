module Plutonium::Ui
  class TableToolbarComponent < Plutonium::Ui::Base
    option :resource_class
    option :search_object
    option :actions
  end
end

Plutonium::ComponentRegistry.register :table_toolbar, to: Plutonium::Ui::TableToolbarComponent

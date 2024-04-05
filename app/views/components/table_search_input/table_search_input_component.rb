module Plutonium::Ui
  class TableSearchInputComponent < Plutonium::Ui::Base
    option :search_object
    # def classname
    #   "custom classnames here #{super}"
    # end
  end
end

Plutonium::ComponentRegistry.register :table_search_input, to: Plutonium::Ui::TableSearchInputComponent

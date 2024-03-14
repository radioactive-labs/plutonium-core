module Plutonium::UI
  class TableSearchInputComponent < Plutonium::UI::Base
    option :search_object
    # def classname
    #   "custom classnames here #{super}"
    # end
  end
end

Plutonium::ComponentRegistry.register :table_search_input, to: Plutonium::UI::TableSearchInputComponent

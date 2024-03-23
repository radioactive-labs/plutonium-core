module Plutonium::UI
  class TabBarComponent < Plutonium::UI::Base
    # def base_classname
    #   "base classnames here"
    # end
  end
end

Plutonium::ComponentRegistry.register :tab_bar, to: Plutonium::UI::TabBarComponent

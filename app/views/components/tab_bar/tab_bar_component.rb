module Plutonium::Ui
  class TabBarComponent < Plutonium::Ui::Base
    # def base_classname
    #   "base classnames here"
    # end
  end
end

Plutonium::ComponentRegistry.register :tab_bar, to: Plutonium::Ui::TabBarComponent

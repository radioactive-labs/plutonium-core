module Plutonium::Ui
  class HeaderComponent < Plutonium::Ui::Base
    option :title
  end
end

Plutonium::ComponentRegistry.register :header, to: Plutonium::Ui::HeaderComponent

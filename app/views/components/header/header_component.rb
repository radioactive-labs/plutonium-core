module Plutonium::UI
  class HeaderComponent < Plutonium::UI::Base
    option :title
  end
end

Plutonium::ComponentRegistry.register :header, to: Plutonium::UI::HeaderComponent

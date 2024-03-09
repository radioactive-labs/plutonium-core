module Plutonium::UI
  class Header < Plutonium::UI::Base
    option :title
  end
end

Plutonium::ComponentRegistry.register :header, to: Plutonium::UI::Header

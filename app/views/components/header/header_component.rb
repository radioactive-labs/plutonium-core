module PlutoniumUi
  class HeaderComponent < PlutoniumUi::Base
    option :title
  end
end

Plutonium::ComponentRegistry.register :header, to: PlutoniumUi::HeaderComponent

module PlutoniumUi
  class EmptyCardComponent < PlutoniumUi::Base
    option :message
  end
end

Plutonium::ComponentRegistry.register :empty_card, to: PlutoniumUi::EmptyCardComponent

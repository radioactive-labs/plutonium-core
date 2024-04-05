module Plutonium::Ui
  class EmptyCardComponent < Plutonium::Ui::Base
    option :message
  end
end

Plutonium::ComponentRegistry.register :empty_card, to: Plutonium::Ui::EmptyCardComponent

module Plutonium::UI
  class FormComponent < Plutonium::UI::Base
    option :form
  end
end

Plutonium::ComponentRegistry.register :form, to: Plutonium::UI::FormComponent

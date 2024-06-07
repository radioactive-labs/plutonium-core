module PlutoniumUi
  class InteractiveActionFormComponent < PlutoniumUi::Base
    option :interaction
    option :interactive_action
  end
end

Plutonium::ComponentRegistry.register :interactive_action_form, to: PlutoniumUi::InteractiveActionFormComponent

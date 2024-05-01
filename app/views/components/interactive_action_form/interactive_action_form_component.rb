module Plutonium::Ui
  class InteractiveActionFormComponent < Plutonium::Ui::Base
    option :interaction
    option :interactive_action
  end
end

Plutonium::ComponentRegistry.register :interactive_action_form, to: Plutonium::Ui::InteractiveActionFormComponent

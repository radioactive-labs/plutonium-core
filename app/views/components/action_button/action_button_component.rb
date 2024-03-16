module Plutonium::UI
  class ActionButtonComponent < Plutonium::UI::Base
    option :label
    option :to
    option :method
    option :icon, optional: true
    option :color, optional: true
    option :variant, optional: true
    option :size, default: proc { :sm }
    option :turbo_frame, optional: true
    option :confirmation, optional: true
  end
end

Plutonium::ComponentRegistry.register :action_button, to: Plutonium::UI::ActionButtonComponent

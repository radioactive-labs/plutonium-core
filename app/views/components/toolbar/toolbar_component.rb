module Plutonium::UI
  class ToolbarComponent < Plutonium::UI::Base
    option :resource
    option :actions, default: proc { {} }

    def classname
      "flex flex-col md:flex-row items-center justify-between space-y-3 md:space-y-0 md:space-x-4 #{super}"
    end

    private

    def toolbar_actions_classes
      "w-full md:w-auto flex flex-col md:flex-row space-y-1 md:space-y-0 items-stretch md:items-center justify-end flex-shrink-0"
    end
  end
end

Plutonium::ComponentRegistry.register :toolbar, to: Plutonium::UI::ToolbarComponent

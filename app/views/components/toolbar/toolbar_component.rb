module PlutoniumUi
  class ToolbarComponent < PlutoniumUi::Base
    option :resource
    option :actions, default: proc { {} }

    private

    def base_attributes
      {
        classname: "flex flex-col md:flex-row items-center justify-between space-y-3 md:space-y-0 md:space-x-4",
        toolbar_actions_classname: "w-full md:w-auto flex flex-col md:flex-row space-y-1 md:space-y-0 items-stretch md:items-center justify-end shrink-0",
        controller: "toolbar"
      }
    end

    def filtered_attributes
      %i[toolbar_actions_classname]
    end

    def toolbar_actions_classname
      raw_attributes_hash[:toolbar_actions_classname]
    end
  end
end

Plutonium::ComponentRegistry.register :toolbar, to: PlutoniumUi::ToolbarComponent

module Plutonium
  module Core
    module Presenters
      module ActionDefinitions
        extend ActiveSupport::Concern

        def actions
          action_definitions
        end

        private

        def action_definitions = @action_definitions ||= Plutonium::Core::Actions::Collection.new

        def define_action(name, action)
          action_definitions[name] = action
        end

        def action_defined?(name)
          action_definitions.key? name
        end
      end
    end
  end
end

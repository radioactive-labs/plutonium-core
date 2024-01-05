module Plutonium
  module UI
    module Concerns
      module DefinesActions
        def action_definitions
          @action_definitions
        end

        def with_actions(*names)
          names.flatten.each do |name|
            raise StandardError, "Action '#{name}' is not defined" unless action_defined?(name)

            @enabled_actions[name] = true
          end
          self
        end

        def define_action(action)
          @action_definitions[action.name] = action
          self
        end

        def only!(*names)
          @enabled_actions.slice!(*names.flatten)
          self
        end

        def except!(*names)
          @enabled_actions.except!(*names.flatten)
          self
        end

        def permitted_actions_for(policy)
          permitted_actions = @enabled_actions.keys.select { |name| policy.send :"#{name}?" }
          @action_definitions.slice(*permitted_actions)
        end

        def action_defined?(name)
          @action_definitions.key? name
        end

        private

        def initialize_actions_definer
          @enabled_actions = {} # using hash since keys act as an ordered set
          @action_definitions = {}
        end
      end
    end
  end
end

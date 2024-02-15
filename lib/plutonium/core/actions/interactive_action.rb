module Plutonium
  module Core
    module Actions
      class InteractiveAction < Plutonium::Core::Action
        include Plutonium::Core::Definers::InputDefiner

        Context = Data.define :resource_class

        attr_reader :interaction, :inline, :inputs

        def initialize(name, *args, interaction:, **kwargs)
          set_interaction interaction

          kwargs[:route_options] ||= build_route_options name
          kwargs.reverse_merge! action_options
          super(name, *args, **kwargs)
        end

        def confirmation
          super || (inline ? "#{label}?" : nil)
        end

        private

        def resource_class = interaction

        def action_options
          {
            collection_action: action_type == :interactive_bulk_resource_action,
            collection_record_action: action_type == :interactive_resource_action,
            record_action: action_type == :interactive_resource_action,
            bulk_action: action_type == :interactive_bulk_resource_action
          }
        end

        def set_interaction(interaction)
          @interaction = interaction
          @inputs = defined_inputs_for(interaction.filters.keys - [:resource, :resources])
          @inline = @inputs.blank? unless inline == false
        end

        def build_route_options(name)
          method = inline ? :post : :get
          action = action_type
          options = { interactive_action: name }

          RouteOptions.new action:, method:, options:
        end

        def action_type
          @action_type ||= if interaction.filters.key? :resource
                              :interactive_resource_action
                           elsif interaction.filters.key? :resources
                              :interactive_bulk_resource_action
                           else
                              raise NotImplementedError, "unable to determine action_type of #{interaction}"
                           end

        end
      end
    end
  end
end

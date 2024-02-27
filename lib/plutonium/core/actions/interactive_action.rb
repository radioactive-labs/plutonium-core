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
            # TODO: move these into config
            collection_action: [:interactive_resource_collection_action,
              :interactive_resource_recordless_action].include?(action_type),
            collection_record_action: action_type == :interactive_resource_record_action,
            record_action: action_type == :interactive_resource_record_action,
            bulk_action: action_type == :interactive_resource_collection_action
          }
        end

        def set_interaction(interaction)
          @interaction = interaction
          @inputs = defined_inputs_for(*(interaction.filters.keys - [:resource, :resources]))
          @inline = @inputs.blank? unless inline == false
        end

        def build_route_options(name)
          method = inline ? :post : :get
          action = action_type
          options = {interactive_action: name}

          RouteOptions.new action:, method:, options:
        end

        def action_type
          if interaction.filters.key? :resource
            :interactive_resource_record_action
          elsif interaction.filters.key? :resources
            :interactive_resource_collection_action
          else
            :interactive_resource_recordless_action
          end
        end
      end
    end
  end
end

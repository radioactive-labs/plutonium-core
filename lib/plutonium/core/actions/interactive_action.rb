module Plutonium
  module Core
    module Actions
      class InteractiveAction < Plutonium::Core::Action
        include Plutonium::Core::Presenters::FieldDefinitions

        Context = Data.define :resource_class

        attr_reader :interaction, :inline, :inputs

        def initialize(name, *args, interaction:, inline: nil, **kwargs)
          set_interaction interaction
          set_inline inline

          # some placement options are not compatible, depending on the interaction config
          # TODO: turn them off forcefully if detected
          # e.g. collection_action: true is not compatible with interactions that specify a resource

          kwargs[:route_options] ||= RouteOptions.new action: :custom_action, options: { custom_action: name }
          kwargs.reverse_merge! action_options
          super(name, *args, **kwargs)
        end

        private

        def action_options = {}

        def resource_class = interaction

        def set_interaction(interaction)
          @interaction = interaction
          @inputs = inputs_for(interaction.filters.keys - [:resource])
        end

        def set_inline(inline)
          @inline = case inline
                    when nil, true
                      @enabled_inputs.blank?
                    else
                      false
                    end
        end
      end
    end
  end
end

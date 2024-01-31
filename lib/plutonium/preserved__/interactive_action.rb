module Plutonium
  module UI
    module Action
      class InteractiveAction < Action
        include Plutonium::UI::Concerns::DefinesInputs

        attr_reader :interaction

        def with_interaction(interaction, inline: nil)
          @interaction = interaction
          setup_interaction_inputs

          @route.action = :custom_action
          @route.options[:custom_action] = name

          @inline = case inline
          when nil, true
            @enabled_inputs.blank?
          else
            false
          end

          if @inline
            @route.method = :post
            with_confirmation "#{name.to_s.titleize}?"
          end

          self
        end

        def turbo_frame
          "modal"
        end

        private

        def setup_interaction_inputs
          initialize_inputs_definer interaction.new
          with_inputs(interaction.filters.keys - [:resource])
        end
      end
    end
  end
end

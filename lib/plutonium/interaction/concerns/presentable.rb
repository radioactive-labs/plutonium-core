module Plutonium
  module Interaction
    module Concerns
      # Provides presentation-related functionality for interactions.
      #
      # This module allows interactions to define metadata such as labels, icons,
      # and descriptions, which can be used for UI generation or documentation.
      #
      # @example
      #   class MyInteraction < Plutonium::Interaction::Base
      #     include Plutonium::Interaction::Concerns::Presentable
      #
      #     presents label: "My Interaction",
      #              icon: "star",
      #              description: "Does something awesome"
      #
      #     # ... rest of the interaction
      #   end
      module Presentable
        extend ActiveSupport::Concern

        included do
          class_attribute :presentation_metadata, default: {}
        end

        class_methods do
          # Defines presentation metadata for the interaction.
          #
          # @param options [Hash] The presentation options.
          # @option options [String] :label The label for the interaction.
          # @option options [String] :icon The icon for the interaction.
          # @option options [String] :description The description of the interaction.
          def presents(**options)
            self.presentation_metadata = options
          end

          # Returns the label for the interaction.
          #
          # @return [String] The label defined in the presentation metadata or a default generated from the class name.
          def label
            presentation_metadata[:label] || name.demodulize.titleize
          end

          # Returns the icon for the interaction.
          #
          # @return [String, nil] The icon defined in the presentation metadata.
          def icon
            presentation_metadata[:icon]
          end

          # Returns the description for the interaction.
          #
          # @return [String, nil] The description defined in the presentation metadata.
          def description
            presentation_metadata[:description]
          end
        end

        def label
          self.class.label
        end

        def icon
          self.class.icon
        end

        def description
          self.class.description
        end
      end
    end
  end
end

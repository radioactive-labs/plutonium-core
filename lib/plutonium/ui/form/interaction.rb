# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Interaction < Resource
        def initialize(interaction, *, **options, &)
          options[:key] = :interaction
          options[:resource_fields] = interaction.attribute_names.map(&:to_sym) - %i[resource resources]
          options[:resource_definition] = interaction

          super
        end

        private

        def form_action
          # interactive action forms post to the same page
          nil
        end

        def initialize_attributes
          super
          attributes.fetch(:data_turbo) { attributes[:data_turbo] = object.turbo.to_s }
        end

        def submit_button(*, **)
          super do
            object.label
          end
        end
      end
    end
  end
end

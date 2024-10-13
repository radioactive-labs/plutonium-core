# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Query < Resource
        def initialize(interaction, *, **options, &)
          options[:key] = :q
          options[:resource_fields] = interaction.defined_inputs.keys
          options[:resource_definition] = interaction

          super
        end

        private

        def form_action
          # query forms post to the same page
          nil
        end
      end
    end
  end
end

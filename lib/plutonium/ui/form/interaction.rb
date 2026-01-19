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
          # Build the correct commit URL for the interactive action
          action = helpers.current_interactive_action
          return nil unless action

          # Create route options for the commit action (convert GET to POST action)
          commit_route_options = action.route_options.merge(
            Plutonium::Action::RouteOptions.new(
              method: :post,
              action: commit_action_name(action.route_options.url_options[:action])
            )
          )

          # Use existing infrastructure to build the URL
          subject = action.record_action? ? helpers.resource_record! : helpers.resource_class
          helpers.route_options_to_url(commit_route_options, subject)
        end

        def commit_action_name(action_name)
          case action_name
          when :interactive_record_action
            :commit_interactive_record_action
          when :interactive_resource_action
            :commit_interactive_resource_action
          when :interactive_collection_action
            :commit_interactive_bulk_action
          else
            action_name
          end
        end

        def initialize_attributes
          super
          attributes[:id] = :interaction_form
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

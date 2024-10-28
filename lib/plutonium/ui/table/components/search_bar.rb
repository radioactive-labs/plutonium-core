# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class SearchBar < Plutonium::UI::Component::Base
          def view_template
            render current_definition.query_form.new(
              raw_resource_query_params,
              query_object: current_query_object,
              page_size: request.parameters[:limit]
            )
          end

          private

          def render?
            current_query_object.filter_definitions.present? && current_policy.allowed_to?(:search?)
          end
        end
      end
    end
  end
end

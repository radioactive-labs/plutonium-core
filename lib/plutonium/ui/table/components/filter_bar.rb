# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class FilterBar < Plutonium::UI::Component::Base
          def view_template
            original_attributes = Phlex::HTML::EVENT_ATTRIBUTES
            temp_attributes = Phlex::HTML::EVENT_ATTRIBUTES.dup
            temp_attributes.delete("oninput")
            temp_attributes.delete("onclick")
            Phlex::HTML.const_set(:EVENT_ATTRIBUTES, temp_attributes)

            div(class: "space-y-2 mb-4") do
              render current_definition.query_form.new(
                raw_resource_query_params,
                query_object: current_query_object,
                page_size: request.parameters[:limit]
              )
            end
          ensure
            # TODO: remove this once Phlex adds support for SafeValues
            Phlex::HTML.const_set(:EVENT_ATTRIBUTES, original_attributes)
          end

          private

          def render?
            current_query_object.filter_definitions.present? && current_policy.allowed_to?(:filter?)
          end
        end
      end
    end
  end
end

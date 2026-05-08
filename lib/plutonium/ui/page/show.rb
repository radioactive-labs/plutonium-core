# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Show < Base
        private

        def page_title
          current_definition.show_page_title || super || display_name_of(resource_record!)
        end

        def page_description
          current_definition.show_page_description || super
        end

        def page_actions
          super || current_definition.defined_actions.values.select { |a| a.record_action? && a.permitted_by?(current_policy) }
        end

        def render_default_content
          if aside_present?
            div(class: "grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_240px] gap-6") do
              div { render partial("resource_details") }
              aside(class: "hidden lg:block") { render_aside }
            end
          else
            div(class: "max-w-[960px] mx-auto") do
              render partial("resource_details")
            end
          end
        end

        def page_type = :show_page
      end
    end
  end
end

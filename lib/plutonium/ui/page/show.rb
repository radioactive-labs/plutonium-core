# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Show < Base
        private

        def page_title
          current_definition.show_page_title || super || display_name_of(resource_record)
        end

        def page_description
          current_definition.show_page_description || super
        end

        def page_actions
          super || current_definition.defined_actions.values.select { |a| a.record_action? && a.permitted_by?(current_policy) }
        end

        def render_default_content
          render "resource_details"
        end
      end
    end
  end
end

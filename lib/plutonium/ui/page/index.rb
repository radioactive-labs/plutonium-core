# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Index < Base
        private

        def page_title
          super || current_definition.index_page_title || resource_name_plural(resource_class)
        end

        def page_description
          super || current_definition.index_page_description
        end

        def page_actions
          super || current_definition.defined_actions.values.select { |a| a.resource_action? && a.permitted_by?(current_policy) }
        end

        def render_default_content
          render "resource_table"
        end

        def page_type = :index_page
      end
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Edit < Base
        private

        def page_title
          current_definition.edit_page_title || super || "Edit"
        end

        def page_description
          current_definition.edit_page_description || super
        end

        def render_default_content
          render "resource_form"
        end

        def page_type = :edit_page
      end
    end
  end
end

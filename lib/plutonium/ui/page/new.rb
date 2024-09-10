# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class New < Base
        private

        def page_title
          current_definition.new_page_title || super || "New"
        end

        def page_description
          current_definition.new_page_description || super
        end

        def render_default_content
          render "resource_form"
        end
      end
    end
  end
end

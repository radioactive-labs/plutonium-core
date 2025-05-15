# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class InteractiveAction < Base
        private

        def page_title
          current_interactive_action.label || super
        end

        def page_description
          current_interactive_action.description || super
        end

        def render_default_content
          render partial("interactive_action_form")
        end

        def page_type = :interactive_action_page
      end
    end
  end
end

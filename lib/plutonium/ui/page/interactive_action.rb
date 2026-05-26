# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class InteractiveAction < Base
        include Phlex::Rails::Helpers::TurboFrameTag

        private

        def page_title
          current_interactive_action.label || super
        end

        def page_description
          current_interactive_action.description || super
        end

        def render_default_content
          if in_modal?
            modal_class = Plutonium::UI::Modal::Base.class_for_mode(
              current_interactive_action.modal_mode(current_definition)
            )

            render modal_class.new(
              title: page_title,
              description: page_description,
              size: current_interactive_action.modal_size(current_definition)
            ) do
              render partial("interactive_action_form")
            end
          else
            div(class: "pb-20") { render partial("interactive_action_form") }
          end
        end

        def page_type = :interactive_action_page
      end
    end
  end
end

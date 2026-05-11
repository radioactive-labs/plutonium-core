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
            modal_class = (current_interactive_action.modal == :slideover) ?
              Plutonium::UI::Modal::Slideover : Plutonium::UI::Modal::Centered

            render modal_class.new(
              title: page_title,
              description: page_description
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

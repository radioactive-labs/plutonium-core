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
          if in_modal?
            render_modal_form
          else
            div(class: "pb-20") { render partial("resource_form") }
          end
        end

        def render_modal_form
          modal_class = (current_definition.modal == :centered) ?
            Plutonium::UI::Modal::Centered : Plutonium::UI::Modal::Slideover
          render modal_class.new(
            title: page_title,
            description: page_description,
            size: current_definition.modal_size
          ) do
            render partial("resource_form")
          end
        end

        def page_type = :new_page
      end
    end
  end
end

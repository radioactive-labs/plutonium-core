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

        def page_type = :edit_page
      end
    end
  end
end

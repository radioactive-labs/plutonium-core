# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Edit < Base
        private

        def page_title
          current_definition.edit_page_title || super || "Edit #{resource_name(resource_class, 1)}"
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
          modal_class = Plutonium::UI::Modal::Base.class_for_mode(current_definition.modal_mode)
          render modal_class.new(
            title: page_title,
            description: page_description,
            size: current_definition.modal_size,
            # Opens this form standalone in a NEW TAB (target=_blank), so the
            # modal — and anything already typed into it — stays put.
            open_full_url: request.path
          ) do
            render partial("resource_form")
          end
        end

        def page_type = :edit_page
      end
    end
  end
end

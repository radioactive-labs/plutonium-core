# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Edit < Base
        private

        def page_title
          current_definition.edit_page_title || super || "Edit #{display_name_of(resource_record)}"
        end

        def page_description
          current_definition.edit_page_description || super
        end

        def render_default_content
          form = helpers.controller.instance_variable_get :@form
          render "resource_form", form: form
        end
      end
    end
  end
end
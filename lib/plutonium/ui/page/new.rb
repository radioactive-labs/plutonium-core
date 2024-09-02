# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class New < Base
        private

        def page_title
          current_definition.new_page_title || super || "New #{resource_name(resource_record)}"
        end

        def page_description
          current_definition.new_page_description || super
        end

        def render_default_content
          form = helpers.controller.instance_variable_get :@form
          render "resource_form", form: form
        end
      end
    end
  end
end

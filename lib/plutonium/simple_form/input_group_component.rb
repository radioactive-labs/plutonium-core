require "simple_form"

module Plutonium
  module SimpleForm
    module InputGroupComponent
      def prepend(_wrapper_options = nil)
        template.content_tag(:span, options[:prepend], class: "input-group-text")
      end

      def append(_wrapper_options = nil)
        template.content_tag(:span, options[:append], class: "input-group-text")
      end
    end
  end
end
# Register with simple_form
SimpleForm.include_component(Plutonium::SimpleForm::InputGroupComponent)

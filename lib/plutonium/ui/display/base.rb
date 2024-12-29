# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Base < Phlexi::Display::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          def association_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Association, :association, **, &)
          end

          def markdown_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Markdown, :markdown, **, &)
          end

          def attachment_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Attachment, :attachment, **, &)
          end
        end

        private

        def fields_wrapper(&)
          div(class: themed(:fields_wrapper)) {
            yield
          }
        end
      end
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Base < Phlexi::Table::Base
        include Plutonium::UI::Component::Behaviour

        class Display < Plutonium::UI::Display::Base
          class Builder < Builder
            def attachment_tag(**, &)
              create_component(Plutonium::UI::Table::Components::Attachment, :attachment, **, &)
            end
          end
        end
      end
    end
  end
end

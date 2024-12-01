# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Component
        class Association < Phlexi::Display::Components::Association
          include Plutonium::UI::Component::Methods

          def render_value(value)
            p(**attributes) {
              if registered_resources.include?(value.class)
                href = resource_url_for(value, parent: (field.association_reflection.macro == :has_many) ? field.object : nil)
                a(class: themed(:link), href:) {
                  display_name_of value
                }
              else
                display_name_of value
              end
            }
          end
        end
      end
    end
  end
end

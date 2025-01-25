# frozen_string_literal: true

require "redcarpet"

module Plutonium
  module UI
    module Display
      module Components
        class PhlexiRender < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue
          include Plutonium::UI::Component::Behaviour

          def render_value(value)
            phlexi_render(build_phlexi_component(value)) {
              p(**attributes) {
                value
              }
            }
          end

          protected

          def build_attributes
            super
            @builder = attributes.delete(:with)
          end

          def build_phlexi_component(value)
            raise "Required option, :with not passed" unless @builder

            @builder.call(value, attributes)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        class Boolean < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            p(**attributes) do
              if value
                render Phlex::TablerIcons::Check.new(class: "inline-block w-5 h-5 text-green-600")
              else
                render Phlex::TablerIcons::X.new(class: "inline-block w-5 h-5 text-red-500")
              end
            end
          end
        end
      end
    end
  end
end

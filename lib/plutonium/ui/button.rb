module Plutonium
  module UI
    class Button
      attr_reader :icon, :label, :button_class

      def initialize(icon:, label:, button_class:)
        @icon = icon
        @label = label
        @button_class = button_class
      end

      class << self
        def create_button(icon: "plus-lg", label: nil, button_class: "primary")
          new icon:, label:, button_class:
        end

        def show_button(icon: "box-arrow-up-right", label: nil, button_class: "primary")
          new icon:, label:, button_class:
        end

        def edit_button(icon: "pencil", label: nil, button_class: "warning")
          new icon:, label:, button_class:
        end

        def destroy_button(icon: "trash", label: nil, button_class: "danger")
          new icon:, label:, button_class:
        end
      end
    end
  end
end

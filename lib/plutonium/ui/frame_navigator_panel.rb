module Plutonium
  module UI
    class FrameNavigatorPanel < Plutonium::UI::Component::Base
      class PanelItem < Plutonium::UI::Component::Base
        def initialize(label:, icon:, **attributes)
          @label = label
          @icon = icon
          @attributes = attributes
        end

        def view_template
          button(
            title: @label,
            style: "display: none",
            class: "text-gray-600 dark:text-gray-300",
            **@attributes
          ) {
            render @icon.new(class: "w-6 h-6")
          }
        end
      end

      class PanelLink < Plutonium::UI::Component::Base
        def initialize(label:, icon:, href:, **attributes)
          @label = label
          @icon = icon
          @href = href
          @attributes = attributes
        end

        def view_template
          a(
            title: @label,
            class: "text-gray-600 dark:text-gray-300",
            href: @href,
            **@attributes
          ) {
            render @icon.new(class: "w-6 h-6")
          }
        end
      end

      class PanelContent < Plutonium::UI::Component::Base
        def initialize(src:)
          @src = src
        end

        def view_template
          DynaFrameHost src: @src, loading: :lazy, data: {"frame-navigator-target": "frame"} do
            SkeletonTable()
          end
        end
      end

      def initialize(title:, src:)
        @title = title
        @src = src
      end

      def view_template
        div(data: {controller: %w[frame-navigator]}) do
          Panel do |panel|
            panel.with_title @title
            panel.with_item PanelItem.new(label: "Home", icon: Phlex::TablerIcons::Home2, data_frame_navigator_target: "homeButton")
            panel.with_item PanelItem.new(label: "Back", icon: Phlex::TablerIcons::ChevronLeft, data_frame_navigator_target: "backButton")
            panel.with_item PanelItem.new(label: "Refresh", icon: Phlex::TablerIcons::RefreshDot, data_frame_navigator_target: "refreshButton")
            panel.with_item PanelLink.new(label: "Maximize", icon: Phlex::TablerIcons::WindowMaximize, href: @src, data_frame_navigator_target: "maximizeLink")
            panel.with_content PanelContent.new(src: @src)
          end
        end
      end
    end
  end
end

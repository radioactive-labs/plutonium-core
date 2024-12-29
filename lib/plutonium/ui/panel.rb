module Plutonium
  module UI
    class Panel < Plutonium::UI::Component::Base
      include Phlex::DeferredRender

      def initialize
        @items = []
      end

      def with_title(title)
        @title = title
      end

      def with_item(item)
        @items << item
      end

      def with_content(content)
        @content = content
      end

      def view_template
        wrapped do
          render_toolbar if render_toolbar?
          render_content if render_content?
        end
      end

      private

      def wrapped(&)
        div(class: "mt-6", &)
      end

      def render_toolbar
        div(class: %(flex justify-between items-center mb-4)) do
          if @title
            h5(class: %(text-2xl font-bold tracking-tight text-gray-900 dark:text-white)) do
              @title
            end
          end
          div(class: "flex space-x-4") do
            @items.each do |item|
              render item
            end
          end
        end
      end

      def render_content
        render @content
      end

      def render_toolbar?
        @title || @items
      end

      def render_content?
        @content
      end
    end
  end
end

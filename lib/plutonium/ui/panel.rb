module Plutonium
  module UI
    # A lightweight panel: optional title + action items rendered as a small
    # floating cluster in the top-right of the panel; content fills the panel
    # body. No outer card chrome — the panel sits flush in its host.
    class Panel < Plutonium::UI::Component::Base
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

      def before_template(&)
        vanish(&)
        super
      end

      def view_template
        render_toolbar if render_toolbar?
        render_content if render_content?
      end

      private

      def render_toolbar
        div(class: "flex items-center justify-end gap-0.5 mb-2") do
          if @title.present?
            span(class: "mr-auto text-[10px] font-semibold uppercase tracking-wider text-[var(--pu-text-muted)]") { @title }
          end
          @items.each { |item| render item }
        end
      end

      def render_content
        render @content
      end

      def render_toolbar?
        @title.present? || @items.any?
      end

      def render_content?
        @content
      end
    end
  end
end

# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Base < Plutonium::UI::Component::Base
        def initialize(page_title: nil, page_description: nil, page_actions: nil)
          @page_title = page_title
          @page_description = page_description
          @page_actions = page_actions
        end

        def view_template(&)
          render_before_header
          render_header
          render_after_header

          render_before_content
          render_content(&)
          render_after_content

          render_before_footer
          render_footer
          render_after_footer
        end

        private

        attr_reader :page_title, :page_description, :page_actions

        def render_header
          render_before_breadcrumbs
          render_breadcrumbs
          render_after_breadcrumbs

          render_before_page_header
          render_page_header
          render_after_page_header

          render_before_toolbar
          render_toolbar
          render_after_toolbar
        end

        def render_breadcrumbs
          Breadcrumbs()
        end

        def render_page_header
          return unless page_title

          PageHeader(title: page_title, description: page_description, actions: page_actions)
        end

        def render_toolbar
          # Implement toolbar content
        end

        def render_content(&block)
          block ||= proc { render_default_content }

          DynaFrameContent(&block)
        end

        def render_default_content
          raise NotImplementedError, "#{self.class}#render_default_content"
        end

        def render_footer
          # Implement footer content
        end

        # Customization hooks
        def render_before_header
        end

        def render_after_header
        end

        def render_before_breadcrumbs
        end

        def render_after_breadcrumbs
        end

        def render_before_page_header
        end

        def render_after_page_header
        end

        def render_before_toolbar
        end

        def render_after_toolbar
        end

        def render_before_content
        end

        def render_after_content
        end

        def render_before_footer
        end

        def render_after_footer
        end
      end
    end
  end
end

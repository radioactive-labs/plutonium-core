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

        def view_template(&block)
          body = block || proc { render_default_content }

          DynaFrameContent() do
            render_before_header
            render_header
            render_after_header

            render_before_content
            body.call
            render_after_content

            render_before_footer
            render_footer
            render_after_footer
          end
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
          return unless render_breadcrumbs?

          Breadcrumbs()
        end

        def render_breadcrumbs?
          # Hide breadcrumbs when rendered inside a turbo frame — the host
          # page already provides the navigation context (e.g., association
          # tabs on a parent show page).
          return false if in_frame?

          # Check specific page setting first, fall back to global setting
          page_specific_setting = current_definition.send(:"#{page_type}_breadcrumbs")
          page_specific_setting.nil? ? current_definition.breadcrumbs : page_specific_setting
        end

        def render_page_header
          return unless page_title

          PageHeader(title: page_title, description: page_description, actions: page_actions)
        end

        def render_toolbar
          # Implement toolbar content
        end

        def render_default_content
          raise NotImplementedError, "#{self.class}#render_default_content"
        end

        def render_footer
          # Implement footer content
        end

        # Renders the optional aside (right-side panel) on show pages.
        # No-op by default; future metadata DSL will populate this slot.
        def render_aside
        end

        # True when the show layout should reserve space for the aside.
        # Returns false by default; pages opt-in by overriding.
        def aside_present? = false

        # True when the page is rendered inside any turbo frame.
        def in_frame? = current_turbo_frame.present?

        # True when the page is rendered inside the remote_modal turbo frame.
        # Used by form pages to suppress the sticky footer (modal owns its own footer).
        def in_modal? = current_turbo_frame == "remote_modal"

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

        def page_type = raise NotImplementedError, "#{self.class}#page_type"
      end
    end
  end
end

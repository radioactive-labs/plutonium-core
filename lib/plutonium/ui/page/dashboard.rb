# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      # The page a registered dashboard renders: the standard page header
      # (title + description from `presents`) over the card grid. Keeps the
      # `render_before_*` / `render_after_*` hooks of {Base} so an app can
      # subclass it and add a toolbar or footer without owning the grid.
      class Dashboard < Base
        def initialize(dashboard:)
          @dashboard = dashboard
          super(page_title: dashboard.class.label, page_description: dashboard.class.description)
        end

        def view_template(&)
          DynaFrameContent() do
            div(class: tokens("pu-dashboard-page", width_classes)) do
              render_before_header
              render_header
              render_after_header

              render_before_content
              render_content
              render_after_content

              render_before_footer
              render_footer
              render_after_footer
            end
          end
        end

        private

        attr_reader :dashboard

        def render_content
          render Plutonium::UI::Dashboard::Board.new(dashboard:)
        end

        # A dashboard has no resource definition to consult and is its own
        # navigation root, so it never renders a breadcrumb trail.
        def render_breadcrumbs? = false

        def width_classes
          Plutonium::UI::PageWidth.classes_for(dashboard.class.width)
        end

        def page_type = :dashboard
      end
    end
  end
end

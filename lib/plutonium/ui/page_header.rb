module Plutonium
  module UI
    class PageHeader < Plutonium::UI::Component::Base
      def initialize(title:, description:, actions:)
        @title = title
        @description = description
        @actions = actions || []
      end

      def view_template
        div(class: tokens(
          theme_class(:page, element: :header),
          "sm:flex sm:space-y-0 sm:space-x-md sm:flex-row items-center justify-between space-y-sm mb-lg"
        )) {
          div {
            phlexi_render(@title) {
              render_title @title
            }

            phlexi_render(@description) {
              render_description @description
            }
          }
          div(class: "flex flex-row space-x-sm") {
            render_actions
          }
        }
      end

      private

      def render_title(title)
        h2(class: tokens(theme_class(:page, element: :header_title), "mb-2 text-3xl font-extrabold leading-none tracking-tight text-gray-900 md:text-4xl dark:text-white")) {
          title
        }
      end

      def render_description(description)
        p(class: tokens(theme_class(:page, element: :header_description), "text-gray-500 dark:text-gray-400")) {
          description
        }
      end

      def render_actions
        @actions.each do |action|
          subject = resource_record? || resource_class
          url = route_options_to_url(action.route_options, subject)
          ActionButton(action, url:)
        end
      end
    end
  end
end

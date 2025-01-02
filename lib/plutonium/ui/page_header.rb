module Plutonium
  module UI
    class PageHeader < Plutonium::UI::Component::Base
      def initialize(title:, description:, actions:)
        @title = title
        @description = description
        @actions = actions || []
      end

      def view_template
        div(class: "sm:flex sm:space-y-0 sm:space-x-4 sm:flex-row items-center justify-between space-y-3 mb-6") {
          div {
            phlexi_render(@title) {
              render_title @title
            }

            phlexi_render(@description) {
              render_description @description
            }
          }
          div(class: "flex flex-row space-x-2") {
            render_actions
          }
        }
      end

      private

      def render_title(title)
        h2(class: "mb-2 text-3xl font-extrabold leading-none tracking-tight text-gray-900 md:text-4xl dark:text-white") {
          title
        }
      end

      def render_description(description)
        p(class: "text-gray-500 dark:text-gray-400") {
          description
        }
      end

      def render_actions
        @actions.each do |action|
          url = resource_url_for(resource_record? || resource_class, *action.route_options.url_args, **action.route_options.url_options)
          ActionButton(action, url:)
        end
      end
    end
  end
end

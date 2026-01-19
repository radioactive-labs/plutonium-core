module Plutonium
  module UI
    class PageHeader < Plutonium::UI::Component::Base
      def initialize(title:, description:, actions:)
        @title = title
        @description = description
        @actions = actions || []
      end

      def view_template
        div(class: "sm:flex sm:space-y-0 sm:gap-6 sm:flex-row items-center justify-between space-y-4 mb-8") {
          div {
            phlexi_render(@title) {
              render_title @title
            }

            phlexi_render(@description) {
              render_description @description
            }
          }
          div(class: "flex flex-row gap-3") {
            render_actions
          }
        }
      end

      private

      def render_title(title)
        h2(class: "mb-2 text-3xl font-bold leading-none tracking-tight text-[var(--pu-text)] md:text-4xl") {
          title
        }
      end

      def render_description(description)
        p(class: "text-lg text-[var(--pu-text-muted)]") {
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

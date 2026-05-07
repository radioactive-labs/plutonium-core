module Plutonium
  module UI
    class PageHeader < Plutonium::UI::Component::Base
      def initialize(title:, description:, actions:)
        @title = title
        @description = description
        @actions = actions || []
      end

      def view_template
        div(class: "flex items-start justify-between gap-4 mb-4") do
          div(class: "min-w-0 flex-1") do
            phlexi_render(@title) { render_title @title } if @title
            phlexi_render(@description) { render_description @description } if @description.present?
          end
          render_actions if @actions.any?
        end
      end

      private

      def render_title(title)
        h1(class: "text-xl font-semibold leading-tight text-[var(--pu-text)] truncate") {
          title
        }
      end

      def render_description(description)
        p(class: "mt-1 text-sm text-[var(--pu-text-muted)]") {
          description
        }
      end

      def render_actions
        div(class: "flex flex-row items-center gap-2") do
          # Primary actions shown as prominent buttons
          primary_actions.each do |action|
            url = route_options_to_url(action.route_options, action_subject)
            ActionButton(action, url:)
          end

          # Secondary and danger actions in a dropdown
          if dropdown_actions.any?
            div(class: "relative") do
              ActionsDropdown(actions: dropdown_actions, subject: action_subject)
            end
          end
        end
      end

      def action_subject
        @action_subject ||= resource_record? || resource_class
      end

      def primary_actions
        @primary_actions ||= @actions.select { |a| a.category.primary? }.sort_by(&:position)
      end

      def dropdown_actions
        @dropdown_actions ||= @actions.reject { |a| a.category.primary? }.sort_by(&:position)
      end
    end
  end
end

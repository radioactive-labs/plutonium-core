# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class BulkActionsToolbar < Plutonium::UI::Component::Base
          include Phlex::Rails::Helpers::LinkTo

          def initialize(bulk_actions:)
            @bulk_actions = bulk_actions
          end

          def view_template
            # Always render toolbar - hidden by default, Stimulus shows it when items are selected
            div(
              class: "hidden mb-4 p-3 bg-primary-50 dark:bg-primary-900/20 rounded-lg flex items-center gap-4",
              data: {bulk_actions_target: "toolbar"}
            ) do
              render_selected_count
              render_action_buttons
            end
          end

          private

          def render_selected_count
            span(class: "text-sm font-medium text-primary-700 dark:text-primary-300") do
              span(data: {bulk_actions_target: "selectedCount"}) { "0" }
              plain " selected"
            end
          end

          def render_action_buttons
            div(class: "flex gap-2") do
              @bulk_actions.each do |action|
                render_action_button(action)
              end
            end
          end

          def render_action_button(action)
            url = route_options_to_url(action.route_options, resource_class)

            link_to(
              url,
              class: button_classes(action),
              data: {
                bulk_actions_target: "actionButton",
                bulk_action_name: action.name,
                bulk_action_url: url,
                turbo_frame: action.turbo_frame
              }
            ) do
              if action.icon
                render action.icon.new(class: "h-4 w-4")
              end
              span { action.label }
            end
          end

          def button_classes(action)
            base = "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-lg focus:outline-none focus:ring-2"

            color = case action.color || action.category&.to_sym
            when :danger
              "bg-danger-100 text-danger-700 hover:bg-danger-200 focus:ring-danger-300 dark:bg-danger-700 dark:text-danger-100 dark:hover:bg-danger-600"
            when :warning
              "bg-warning-100 text-warning-700 hover:bg-warning-200 focus:ring-warning-300 dark:bg-warning-700 dark:text-warning-100 dark:hover:bg-warning-600"
            when :success
              "bg-success-100 text-success-700 hover:bg-success-200 focus:ring-success-300 dark:bg-success-700 dark:text-success-100 dark:hover:bg-success-600"
            else
              "bg-primary-100 text-primary-700 hover:bg-primary-200 focus:ring-primary-300 dark:bg-primary-700 dark:text-primary-100 dark:hover:bg-primary-600"
            end

            "#{base} #{color}"
          end
        end
      end
    end
  end
end

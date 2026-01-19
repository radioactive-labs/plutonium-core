# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class BulkActionsToolbar < Plutonium::UI::Component::Base
          include Phlex::Rails::Helpers::LinkTo

          # Color to CSS class mapping for soft button variants
          COLOR_CLASSES = {
            primary: "pu-btn-soft-primary",
            success: "pu-btn-soft-success",
            warning: "pu-btn-soft-warning",
            danger: "pu-btn-soft-danger",
            info: "pu-btn-soft-info",
            accent: "pu-btn-soft-accent",
            secondary: "pu-btn-soft-secondary"
          }.freeze

          def initialize(bulk_actions:)
            @bulk_actions = bulk_actions
          end

          def view_template
            # Always render toolbar - hidden by default, Stimulus shows it when items are selected
            div(
              class: "hidden flex pu-toolbar",
              data: {bulk_actions_target: "toolbar"}
            ) do
              render_selected_count
              render_action_buttons
            end
          end

          private

          def render_selected_count
            span(class: "pu-toolbar-text") do
              span(data: {bulk_actions_target: "selectedCount"}) { "0" }
              plain " selected"
            end
          end

          def render_action_buttons
            div(class: "pu-toolbar-actions") do
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
            color_key = (action.color || action.category)&.to_sym || :primary
            color_class = COLOR_CLASSES[color_key] || COLOR_CLASSES[:primary]
            "pu-btn pu-btn-sm #{color_class}"
          end
        end
      end
    end
  end
end

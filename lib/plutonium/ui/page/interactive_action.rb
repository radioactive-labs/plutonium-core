# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class InteractiveAction < Base
        include Phlex::Rails::Helpers::TurboFrameTag

        private

        def page_title
          current_interactive_action.label || super
        end

        def page_description
          current_interactive_action.description || super
        end

        def render_default_content
          if current_turbo_frame == "remote_modal"
            dialog(
              closedby: "any",
              class: "rounded-[var(--pu-radius-lg)] w-full max-w-3xl
                      bg-[var(--pu-surface)]
                      border border-[var(--pu-border)]
                      backdrop:bg-black/60 backdrop:backdrop-blur-sm
                      top-auto md:top-1/2 md:-translate-y-1/2 left-1/2 -translate-x-1/2
                      max-h-[80%] p-6
                      hidden open:flex flex-col
                      relative opacity-0 open:opacity-100
                      transition-opacity duration-300 ease-in-out",
              style: "box-shadow: var(--pu-shadow-lg)",
              data: {controller: "remote-modal"}
            ) do
              # Close button
              button(
                type: "button",
                class: "absolute top-4 right-4 p-2 text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] transition-colors duration-200",
                data: {action: "remote-modal#close"},
                "aria-label": "Close dialog"
              ) do
                svg(
                  class: "w-5 h-5",
                  fill: "none",
                  stroke: "currentColor",
                  viewBox: "0 0 24 24",
                  xmlns: "http://www.w3.org/2000/svg"
                ) do |s|
                  s.path(
                    stroke_linecap: "round",
                    stroke_linejoin: "round",
                    stroke_width: "2",
                    d: "M6 18L18 6M6 6l12 12"
                  )
                end
              end

              render_page_header
              render partial("interactive_action_form")
            end
          else
            render partial("interactive_action_form")
          end
        end

        def page_type = :interactive_action_page
      end
    end
  end
end

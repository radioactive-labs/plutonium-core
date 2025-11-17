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
          if helpers.current_turbo_frame == "remote_modal"
            dialog(
              closedby: "any",
              class: "rounded w-full max-w-3xl
                      bg-surface dark:bg-surface-dark
                      border border-gray-200 dark:border-gray-700
                      shadow-lg dark:shadow-gray-900/20
                      backdrop:bg-black/60 backdrop:backdrop-blur-sm
                      top-auto md:top-1/2 md:-translate-y-1/2 left-1/2 -translate-x-1/2
                      max-h-[80%] p-lg
                      hidden open:flex flex-col
                      relative opacity-0 open:opacity-100
                      transition-opacity duration-300 ease-in-out",
              data: {controller: "remote-modal"}
            ) do
              # Close button
              button(
                type: "button",
                class: "absolute top-4 right-4 p-sm text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors duration-200",
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

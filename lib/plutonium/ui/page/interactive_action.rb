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
              class: "rounded-md w-full max-w-3xl
                      bg-white dark:bg-gray-800
                      border border-gray-200 dark:border-gray-700
                      shadow-lg dark:shadow-gray-900/20
                      backdrop:bg-black/60 backdrop:backdrop-blur-sm
                      top-auto md:top-1/2 md:-translate-y-1/2 left-1/2 -translate-x-1/2
                      max-h-[80%] p-6
                      hidden open:flex flex-col
                      relative opacity-0 open:opacity-100
                      transition-opacity duration-300 ease-in-out",
              data: {controller: "remote-modal"}
            ) do
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

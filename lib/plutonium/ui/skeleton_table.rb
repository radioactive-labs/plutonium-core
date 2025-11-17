module Plutonium
  module UI
    class SkeletonTable < Plutonium::UI::Component::Base
      def view_template
        div(
          role: "status",
          class:
            "p-md space-y-md border border-gray-200 divide-y divide-gray-200 rounded shadow motion-safe:animate-pulse dark:divide-gray-700 md:p-lg dark:border-gray-700"
        ) do
          div(class: "flex items-center justify-between") do
            div do
              div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-gray-600 w-24 mb-sm")
              div(class: "w-32 h-2 bg-elevated rounded-full dark:bg-elevated-dark")
            end
            div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-elevated-dark w-12")
          end
          div(class: "flex items-center justify-between pt-md") do
            div do
              div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-gray-600 w-24 mb-sm")
              div(class: "w-32 h-2 bg-elevated rounded-full dark:bg-elevated-dark")
            end
            div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-elevated-dark w-12")
          end
          span(class: "sr-only") { "Loading..." }
        end
      end
    end
  end
end

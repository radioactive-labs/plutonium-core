module Plutonium
  module UI
    class SkeletonTable < Plutonium::UI::Component::Base
      def view_template
        div(
          role: "status",
          class:
            "p-4 space-y-4 border border-gray-200 divide-y divide-gray-200 rounded shadow motion-safe:animate-pulse dark:divide-gray-700 md:p-6 dark:border-gray-700"
        ) do
          div(class: "flex items-center justify-between") do
            div do
              div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-gray-600 w-24 mb-2.5")
              div(class: "w-32 h-2 bg-gray-200 rounded-full dark:bg-gray-700")
            end
            div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-gray-700 w-12")
          end
          div(class: "flex items-center justify-between pt-4") do
            div do
              div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-gray-600 w-24 mb-2.5")
              div(class: "w-32 h-2 bg-gray-200 rounded-full dark:bg-gray-700")
            end
            div(class: "h-2.5 bg-gray-300 rounded-full dark:bg-gray-700 w-12")
          end
          span(class: "sr-only") { "Loading..." }
        end
      end
    end
  end
end

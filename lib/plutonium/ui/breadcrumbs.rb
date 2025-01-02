module Plutonium
  module UI
    class Breadcrumbs < Plutonium::UI::Component::Base
      include Phlex::Rails::Helpers::ActionName
      include Phlex::Rails::Helpers::LinkTo

      def view_template
        nav(
          class:
            "flex py-3 text-gray-700 mb-2",
          aria_label: "Breadcrumb"
        ) do
          ol(
            class:
              "inline-flex items-center space-x-1 md:space-x-2 rtl:space-x-reverse"
          ) do
            # Dashboard
            li(class: "inline-flex items-center") do
              a(
                href: helpers.root_path,
                class:
                  "inline-flex items-center text-sm font-medium text-gray-700 hover:text-primary-600 dark:text-gray-200 dark:hover:text-white"
              ) do
                svg(
                  class: "w-3 h-3 me-2.5",
                  aria_hidden: "true",
                  xmlns: "http://www.w3.org/2000/svg",
                  fill: "currentColor",
                  viewbox: "0 0 20 20"
                ) do |s|
                  s.path(
                    d:
                      "m19.707 9.293-2-2-7-7a1 1 0 0 0-1.414 0l-7 7-2 2a1 1 0 0 0 1.414 1.414L2 10.414V18a2 2 0 0 0 2 2h3a1 1 0 0 0 1-1v-4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v4a1 1 0 0 0 1 1h3a2 2 0 0 0 2-2v-7.586l.293.293a1 1 0 0 0 1.414-1.414Z"
                  )
                end
                plain " Dashboard "
              end
            end

            # Parent
            if current_parent.present?
              # Parent Resource
              li(class: "flex items-center") do
                svg(
                  class: "rtl:rotate-180 block w-3 h-3 mx-1 text-gray-400",
                  aria_hidden: "true",
                  xmlns: "http://www.w3.org/2000/svg",
                  fill: "none",
                  viewbox: "0 0 6 10"
                ) do |s|
                  s.path(
                    stroke: "currentColor",
                    stroke_linecap: "round",
                    stroke_linejoin: "round",
                    stroke_width: "2",
                    d: "m1 9 4-4-4-4"
                  )
                end
                link_to resource_name_plural(current_parent.class),
                  resource_url_for(current_parent.class, parent: nil),
                  class:
                    "ms-1 text-sm font-medium text-gray-700 hover:text-primary-600 md:ms-2 dark:text-gray-200 dark:hover:text-white"
              end

              # Parent Itself
              li(class: "flex items-center") do
                svg(
                  class: "rtl:rotate-180 block w-3 h-3 mx-1 text-gray-400",
                  aria_hidden: "true",
                  xmlns: "http://www.w3.org/2000/svg",
                  fill: "none",
                  viewbox: "0 0 6 10"
                ) do |s|
                  s.path(
                    stroke: "currentColor",
                    stroke_linecap: "round",
                    stroke_linejoin: "round",
                    stroke_width: "2",
                    d: "m1 9 4-4-4-4"
                  )
                end
                link_to display_name_of(current_parent),
                  resource_url_for(current_parent, parent: nil),
                  class:
                    "ms-1 text-sm font-medium text-gray-700 hover:text-primary-600 md:ms-2 dark:text-gray-200 dark:hover:text-white"
              end
            end

            # Record
            if resource_record?
              # Record Resource
              li(class: "flex items-center") do
                svg(
                  class: "rtl:rotate-180 block w-3 h-3 mx-1 text-gray-400",
                  aria_hidden: "true",
                  xmlns: "http://www.w3.org/2000/svg",
                  fill: "none",
                  viewbox: "0 0 6 10"
                ) do |s|
                  s.path(
                    stroke: "currentColor",
                    stroke_linecap: "round",
                    stroke_linejoin: "round",
                    stroke_width: "2",
                    d: "m1 9 4-4-4-4"
                  )
                end
                link_to resource_name_plural(resource_class),
                  resource_url_for(resource_class),
                  class:
                    "ms-1 text-sm font-medium text-gray-700 hover:text-primary-600 md:ms-2 dark:text-gray-200 dark:hover:text-white"
              end

              # Record Itself
              if resource_record!.persisted? && action_name != "show"
                li(class: "flex items-center") do
                  svg(
                    class: "rtl:rotate-180 block w-3 h-3 mx-1 text-gray-400",
                    aria_hidden: "true",
                    xmlns: "http://www.w3.org/2000/svg",
                    fill: "none",
                    viewbox: "0 0 6 10"
                  ) do |s|
                    s.path(
                      stroke: "currentColor",
                      stroke_linecap: "round",
                      stroke_linejoin: "round",
                      stroke_width: "2",
                      d: "m1 9 4-4-4-4"
                    )
                  end
                  link_to display_name_of(resource_record!),
                    resource_url_for(resource_record!),
                    class:
                      "ms-1 text-sm font-medium text-gray-700 hover:text-primary-600 md:ms-2 dark:text-gray-200 dark:hover:text-white"
                end
              end
            end

            # Trailing Caret
            li(class: "flex items-center") do
              svg(
                class: "rtl:rotate-180 block w-3 h-3 mx-1 text-gray-400",
                aria_hidden: "true",
                xmlns: "http://www.w3.org/2000/svg",
                fill: "none",
                viewbox: "0 0 6 10"
              ) do |s|
                s.path(
                  stroke: "currentColor",
                  stroke_linecap: "round",
                  stroke_linejoin: "round",
                  stroke_width: "2",
                  d: "m1 9 4-4-4-4"
                )
              end
            end
          end
        end
      end
    end
  end
end

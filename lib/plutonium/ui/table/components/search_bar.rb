# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class SearchBar < Plutonium::UI::Component::Base
          def view_template
            original_attributes = Phlex::HTML::EVENT_ATTRIBUTES
            temp_attributes = Phlex::HTML::EVENT_ATTRIBUTES.dup
            temp_attributes.delete("oninput")
            temp_attributes.delete("onclick")
            Phlex::HTML.const_set(:EVENT_ATTRIBUTES, temp_attributes)

            div(
              class:
                # "p-4 bg-white border border-gray-200 rounded-lg dark:bg-gray-800 dark:border-gray-700 space-y-2 mb-4"
                "space-y-2 mb-4"
            ) do
              search_query = current_query_object.search_query
              query_params = raw_resource_query_params
              render Phlexi::Form(:q, attributes: {class!: nil, data: {controller: "form", turbo_frame: nil}}) {
                div(class: "relative") do
                  div(class: "absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none") do
                    svg(
                      class: "w-5 h-5 text-gray-500 dark:text-gray-400",
                      aria_hidden: "true",
                      fill: "currentColor",
                      viewbox: "0 0 20 20",
                      xmlns: "http://www.w3.org/2000/svg"
                    ) do |s|
                      s.path(
                        fill_rule: "evenodd",
                        d:
                          "M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z",
                        clip_rule: "evenodd"
                      )
                    end
                  end
                  render field(:search, value: search_query)
                    .placeholder("Search...")
                    .input_tag(
                      id: "search",
                      value: search_query,
                      class: "block w-full p-2 pl-10 text-sm text-gray-900 border border-gray-300 rounded-lg bg-gray-50 focus:ring-primary-500 focus:border-primary-500 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500",
                      data: {
                        action: "form#submit",
                        turbo_permanent: true
                      }
                    )

                  render field(:scope, value: query_params[:scope]).input_tag(type: :hidden)
                  render field(:sort_fields, value: query_params[:sort_fields]).input_array_tag do |f|
                    render f.input_tag(type: :hidden)
                  end
                  nest_one(:sort_directions) do |directions|
                    query_params[:sort_directions]&.each do |name, value|
                      render directions.field(name, value:).input_tag(hidden: true)
                    end
                  end
                end
              }

              # div(class: "flex flex-wrap items-center gap-4") do
              #   span(class: "text-sm font-medium text-gray-900 dark:text-white") do
              #     "Filters:"
              #   end
              #   select(
              #     id: "category-filter",
              #     class:
              #       "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
              #   ) do
              #     option(selected: "selected", value: "") { "All Categories" }
              #     option(value: "technology") { "Technology" }
              #     option(value: "science") { "Science" }
              #     option(value: "health") { "Health" }
              #   end
              #   div(class: "flex items-center space-x-2") do
              #     input(
              #       type: "date",
              #       id: "start-date",
              #       class:
              #         "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
              #     )
              #     span(class: "text-gray-500 dark:text-gray-400") { "to" }
              #     input(
              #       type: "date",
              #       id: "end-date",
              #       class:
              #         "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
              #     )
              #   end
              #   select(
              #     id: "author-filter",
              #     class:
              #       "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
              #   ) do
              #     option(selected: "selected", value: "") { "All Authors" }
              #     option(value: "john-doe") { "John Doe" }
              #     option(value: "jane-smith") { "Jane Smith" }
              #   end
              #   button(
              #     onclick: "applyFilters()",
              #     class:
              #       "inline-flex items-center text-white bg-primary-700 hover:bg-primary-800 focus:ring-4 focus:ring-primary-300 font-medium rounded-lg text-sm px-4 py-2 dark:bg-primary-600 dark:hover:bg-primary-700 focus:outline-none dark:focus:ring-primary-800"
              #   ) do
              #     svg(
              #       class: "w-4 h-4 mr-2",
              #       fill: "currentColor",
              #       viewbox: "0 0 20 20",
              #       xmlns: "http://www.w3.org/2000/svg"
              #     ) do |s|
              #       s.path(
              #         fill_rule: "evenodd",
              #         d:
              #           "M3 3a1 1 0 011-1h12a1 1 0 011 1v3a1 1 0 01-.293.707L12 11.414V15a1 1 0 01-.293.707l-2 2A1 1 0 018 17v-5.586L3.293 6.707A1 1 0 013 6V3z",
              #         clip_rule: "evenodd"
              #       )
              #     end
              #     plain " Apply Filters "
              #   end
              #   button(
              #     onclick: "clearFilters()",
              #     class:
              #       "inline-flex items-center text-gray-900 bg-white border border-gray-300 focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm px-4 py-2 dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700"
              #   ) do
              #     svg(
              #       class: "w-4 h-4 mr-2",
              #       fill: "currentColor",
              #       viewbox: "0 0 20 20",
              #       xmlns: "http://www.w3.org/2000/svg"
              #     ) do |s|
              #       s.path(
              #         fill_rule: "evenodd",
              #         d:
              #           "M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z",
              #         clip_rule: "evenodd"
              #       )
              #     end
              #     plain " Clear Filters "
              #   end
              # end
            end
          ensure
            # TODO: remove this once Phlex adds support for SafeValues
            Phlex::HTML.const_set(:EVENT_ATTRIBUTES, original_attributes)
          end

          private

          def render?
            current_query_object.search_filter.present? && current_policy.allowed_to?(:search?)
          end
        end
      end
    end
  end
end

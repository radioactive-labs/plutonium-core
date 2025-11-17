# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Query < Base
        attr_reader :query_object

        def initialize(*, query_object:, page_size:, attributes: {}, **options, &)
          options[:as] = :q
          options[:method] = :get
          attributes = mix(attributes.deep_merge(
            id: :search_form,
            class!: "space-y-sm mb-md",
            controller: "form",
            data: {controller: "form", turbo_frame: nil}
          ))
          super(*, attributes:, **options, &)

          @query_object = query_object
          @page_size = page_size
        end

        def form_template
          render_fields
        end

        private

        def render_fields
          render_search_fields
          render_filter_fields
          div hidden: true do # workaround the fact that input array does not accept other attributes for now
            input(name: "limit", value: @page_size, type: :hidden, hidden: true) if @page_size
            render_sort_fields
            render_scope_fields
          end
        end

        def render_sort_fields
          # q[sort_fields][]=name&q[sort_fields][]=created_at
          field :sort_fields do |name|
            render name.input_array_tag do |array|
              render array.input_tag(type: :hidden, hidden: true)
            end
          end
          # q[sort_directions][created_at]=ASC&q[sort_directions][name]=ASC&
          nest_one :sort_directions do |nested|
            query_object.sort_definitions.each do |filter_name, definition|
              nested.field(filter_name) do |f|
                render f.input_tag(type: :hidden, hidden: true)
              end
            end
          end
        end

        def render_scope_fields
          # q[scope]=&
          return if query_object.scope_definitions.blank?

          render field(:scope).input_tag(type: :hidden, hidden: true)
        end

        def render_search_fields
          # q[search]=&
          return unless query_object.search_filter

          search_query = query_object.search_query
          div(class: "relative") do
            div(class: "absolute inset-y-0 left-0 flex items-center pl-sm pointer-events-none") do
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
                value: search_query,
                class: "block w-full p-sm pl-10 text-sm text-gray-900 border border-gray-300 rounded-sm bg-page focus:ring-primary-500 focus:border-primary-500 dark:bg-elevated-dark dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500",
                data: {
                  action: "form#submit",
                  turbo_permanent: true
                }
              )
          end
        end

        def render_filter_fields
          return if query_object.filter_definitions.blank?

          div(class: "flex flex-wrap items-center gap-md") do
            span(class: "text-sm font-medium text-gray-900 dark:text-white") { "Filters:" }
            div(class: "flex flex-wrap items-center gap-md mr-auto") do
              div class: "flex flex-wrap items-center gap-md" do
                query_object.filter_definitions.each do |filter_name, definition|
                  nest_one filter_name do |nested|
                    definition.defined_inputs.each do |input_name, _|
                      render_defined_field nested, definition, input_name
                    end
                  end
                end
              end
            end
            div(class: "flex flex-wrap items-center gap-sm") do
              actions_wrapper do
                render field(:submit).submit_button_tag(
                  name: nil,
                  class!: "inline-flex items-center text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-sm text-sm px-md py-sm dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
                ) do
                  render Phlex::TablerIcons::Filter.new(class: "w-4 h-4 mr-sm")
                  plain "Apply Filters"
                end

                render field(:reset).submit_button_tag(
                  name: nil,
                  type: :reset,
                  class!: "inline-flex items-center text-gray-900 bg-surface border border-gray-300 focus:outline-none hover:bg-interactive focus:ring-4 focus:ring-gray-200 font-medium rounded-sm text-sm px-md py-sm dark:bg-surface-dark dark:text-white dark:border-gray-600 dark:hover:bg-interactive-dark dark:hover:border-gray-600 dark:focus:ring-gray-700"
                ) do
                  render Phlex::TablerIcons::X.new(class: "w-4 h-4 mr-sm")
                  plain "Clear Filters"
                end
              end
            end
          end
        end

        def form_action
          # query forms post to the same page
          nil
        end

        def render_defined_field(nested, resource_definition, name)
          # field :name, as: :string
          # input :name, as: :string
          # input :description, wrapper: {class: "col-span-full"}
          # input :age, class: "max-h-fit"
          # input :dob do |f|
          #   f.date_tag
          # end

          field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options] : {}

          input_definition = definition.defined_inputs[name] || {}
          input_options = input_definition[:options] || {}

          tag = input_options[:as] || field_options[:as]
          tag_attributes = input_options.except(:wrapper, :as)
          tag_block = input_definition[:block] || ->(f) {
            tag ||= f.inferred_field_component
            f.send(:"#{tag}_tag", **tag_attributes, class: tokens(tag_attributes[:class], "flex-1"))
          }

          field_options = field_options.except(:as)
          nested.field(name, **field_options) do |f|
            f.placeholder(f.label) unless f.placeholder
            render instance_exec(f, &tag_block)
          end
        end
      end
    end
  end
end

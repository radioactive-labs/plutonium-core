# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Query < Base
        attr_reader :query_object

        def initialize(*, query_object:, page_size:, attributes: {}, **options, &)
          attributes[:class!] = "flex flex-wrap items-center gap-4"
          options[:method] = :get
          @page_size = page_size
          super(*, attributes:, **options, &)

          @query_object = query_object
        end

        def form_template
          span(class: "text-sm font-medium text-gray-900 dark:text-white") { "Filters:" }
          div(class: "flex flex-wrap items-center gap-4 mr-auto") {
            render_fields
            input(name: "limit", value: @page_size, type: :hidden) if @page_size
          }
          div(class: "flex flex-wrap items-center gap-2") {
            render_actions
          }
        end

        private

        def render_fields
          render_sort_fields
          render_scope_fields
          render_search_fields
          render_filter_fields
        end

        def render_sort_fields
          # q[sort_directions][created_at]=ASC&q[sort_directions][name]=ASC&
          # q[sort_fields][]=name&q[sort_fields][]=created_at
          div hidden: true do
            field :sort_fields do |name|
              render name.input_array_tag
            end
          end

          nest_one :sort_directions do |nested|
            query_object.sort_definitions.each do |filter_name, definition|
              nested.field(filter_name) do |f|
                render f.string_tag(hidden: true)
              end
            end
          end
        end

        def render_scope_fields
          # q[scope]=&
          return if query_object.scope_definitions.blank?

          render field(:scope).string_tag(hidden: true)
        end

        def render_search_fields
          # q[search]=&
          return unless query_object.search_filter

          render field(:search).string_tag(hidden: true)
        end

        def render_filter_fields
          query_object.filter_definitions.each do |filter_name, definition|
            nest_one filter_name do |nested|
              definition.defined_inputs.each do |input_name, _|
                render_defined_field nested, definition, input_name
              end
            end
          end
        end

        def render_actions
          actions_wrapper {
            render field(:submit).submit_button_tag(
              name: nil,
              class!: "inline-flex items-center text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-4 py-2 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
            ) do
              render Phlex::TablerIcons::Filter.new(class: "w-4 h-4 mr-2")
              plain "Apply Filters"
            end

            render field(:reset).submit_button_tag(
              name: nil,
              type: :reset,
              class!: "inline-flex items-center text-gray-900 bg-white border border-gray-300 focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm px-4 py-2 dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700"
            ) do
              render Phlex::TablerIcons::X.new(class: "w-4 h-4 mr-2")
              plain "Clear Filters"
            end
          }
        end

        def form_action
          # query forms post to the same page
          nil
        end

        def render_defined_field(nested, resource_definition, name)
          # input :name, as: :string
          # input :description, class: "col-span-full"
          # input :age, field: {class: "max-h-fit"}
          # input :dob do |f|
          #   f.date_tag
          # end

          input_definition = resource_definition.defined_inputs[name] || {}
          input_options = input_definition[:options] || {}

          input_tag = input_options[:as]
          input_tag_options = input_options[:field].dup || {}
          input_tag_block = input_definition[:block] || ->(f) {
            input_tag_options[:class] = tokens(input_tag_options[:class], "flex-1")
            input_tag ||= f.inferred_field_component
            f.send(:"#{input_tag}_tag", **input_tag_options)
          }

          field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options] : {}
          nested.field(name, **field_options) do |f|
            f.placeholder(f.label) unless f.placeholder
            render input_tag_block.call(f)
          end
        end
      end
    end
  end
end

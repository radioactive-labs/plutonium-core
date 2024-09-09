# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class PagyInfo < Plutonium::UI::Component::Base
          include Pagy::Frontend

          def initialize(pagy, per_page_options: [5, 10, 20, 50, 100])
            @pagy = pagy
            @per_page_options = (per_page_options + [@pagy.limit]).uniq.sort
          end

          def view_template
            div(class: "flex flex-col md:flex-row justify-between items-center text-sm text-gray-500 dark:text-gray-400") do
              results_info
              per_page_selector
            end
          end

          private

          def results_info
            div do
              plain "Showing "
              b { @pagy.from.to_s }
              plain " to "
              b { @pagy.to.to_s }
              plain " of "
              b { @pagy.count }
              plain " results"
            end
          end

          def per_page_selector
            original_attributes = Phlex::HTML::EVENT_ATTRIBUTES
            temp_attributes = Phlex::HTML::EVENT_ATTRIBUTES.dup
            temp_attributes.delete("onchange")
            Phlex::HTML.const_set(:EVENT_ATTRIBUTES, temp_attributes)

            div(class: "flex items-center space-x-2 mt-2 md:mt-0") do
              label(for: "perPage", class: "mr-2") { "Per page" }
              select(id: "perPage", name: "items", class: select_classes, onchange: "window.location.href=this.value") do
                @per_page_options.each do |option|
                  option(value: page_url(option), selected: option == @pagy.limit) { option.to_s }
                end
              end
            end
          ensure
            # TODO: remove this once Phlex adds support for SafeValues
            Phlex::HTML.const_set(:EVENT_ATTRIBUTES, original_attributes)
          end

          def select_classes
            "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"
          end

          def page_url(limit)
            original_limit = @pagy.vars[:limit]
            @pagy.vars[:limit] = limit
            pagy_url_for(@pagy, @pagy.page)
          ensure
            @pagy.vars[:limit] = original_limit
          end
        end
      end
    end
  end
end

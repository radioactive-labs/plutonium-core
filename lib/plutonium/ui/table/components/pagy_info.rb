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
            div(class: "flex flex-col md:flex-row justify-between items-center text-sm text-[var(--pu-text-muted)]") do
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
            div(
              class: "flex items-center space-x-2 mt-2 md:mt-0",
              data_controller: "select-navigator"
            ) do
              id = "perPage#{SecureRandom.hex}"
              label(for: id, class: "mr-2") { "Per page" }
              select(
                id: id, name: "items", class: select_classes,
                data_action: "change->select-navigator#navigate",
                data_select_navigator_target: "select"
              ) do
                @per_page_options.each do |option|
                  option(value: page_url(option), selected: option == @pagy.limit) { option.to_s }
                end
              end
            end
          end

          def select_classes
            "bg-[var(--pu-surface)] border border-[var(--pu-border)] text-[var(--pu-text)] text-sm rounded-[var(--pu-radius-md)] focus:ring-2 focus:ring-primary-500 focus:border-primary-500 block p-2.5 min-w-[5em]"
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

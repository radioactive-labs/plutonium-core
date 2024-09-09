# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Resource < Plutonium::UI::Component::Base
        attr_reader :collection, :resource_fields

        def initialize(collection, resource_fields:)
          @collection = collection
          @resource_fields = resource_fields
        end

        def view_template
          render_search_bar
          render_scopes_bar

          collection.empty? ? render_empty_card : render_table

          render_footer
        end

        private

        def render_search_bar
          TableSearchBar()
        end

        def render_scopes_bar
          TableScopesBar()
        end

        def render_empty_card
          EmptyCard("No #{resource_name_plural(resource_class)} match your query") {
            action = current_definition.defined_actions[:new]
            if action&.permitted_by?(current_policy)
              url = resource_url_for(resource_class, *action.route_options.url_args, **action.route_options.url_options)
              ActionButton(action, url:)
            end
          }
        end

        def render_table
          render Plutonium::UI::Table::Base.new(collection) do |table|
            @resource_fields.each do |name|
              table.column name, sort_params: current_query_object.sort_params_for(name)
            end

            table.actions do |record|
              policy = policy_for(record:)
              current_definition.defined_actions
                .select { |k, a| a.collection_record_action? && policy.allowed_to?(:"#{k}?") }
                .values
                .each { |action|
                  url = resource_url_for(record, *action.route_options.url_args, **action.route_options.url_options)

                  ActionButton(action, url:, variant: :table)
                }
            end
          end
        end

        def render_footer
          div(class: "sticky bottom-[-2px] p-4 pb-6 w-full z-50 bg-gray-50 dark:bg-gray-900") {
            TableInfo(pagy_instance)
            TablePagination(pagy_instance)
          }
        end
      end
    end
  end
end

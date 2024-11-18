# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Resource < Plutonium::UI::Component::Base
        attr_reader :collection, :resource_fields, :resource_definition

        def initialize(collection, resource_fields:, resource_definition:)
          @collection = collection
          @resource_fields = resource_fields
          @resource_definition = resource_definition
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
            action = resource_definition.defined_actions[:new]
            if action&.permitted_by?(current_policy)
              url = resource_url_for(resource_class, *action.route_options.url_args, **action.route_options.url_options)
              ActionButton(action, url:)
            end
          }
        end

        def render_table
          render Plutonium::UI::Table::Base.new(collection) do |table|
            @resource_fields.each do |name|
              # column :name, as: :string
              # column :description, class: "text-red-700"
              # column :age, align: :end
              # column :dob do |proxy|
              #   proxy.field(:dob).date_tag
              # end

              column_definition = resource_definition.defined_columns[name] || {}
              column_display_options = column_definition[:options] || {}

              display_tag = column_display_options[:as]
              display_tag_options = column_display_options.except(:as, :align)
              display_tag_block = column_definition[:block] || ->(wrapped_object, key) {
                f = wrapped_object.field(key)
                display_tag ||= f.inferred_field_component
                f.send(:"#{display_tag}_tag", **display_tag_options)
              }

              # align_field_to = column_display_options.slice(:align)
              field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options].dup : {}
              field_options = field_options.merge(**column_display_options.slice(:align))
              # field_options[:align] = align_field_to if align_field_to
              table.column name, **field_options, sort_params: current_query_object.sort_params_for(name), &display_tag_block
            end

            table.actions do |wrapped_object|
              record = wrapped_object.unwrapped
              policy = policy_for(record:)

              div(class: "flex space-x-2") do
                resource_definition.defined_actions
                  .select { |k, a| a.collection_record_action? && policy.allowed_to?(:"#{k}?") }
                  .values
                  .each do |action|
                    # TODO: extract this
                    url = case action.route_options.url_resolver
                    when :resource_url_for
                      resource_url_for(record, *action.route_options.url_args, **action.route_options.url_options)
                    else
                      raise NotImplementedError, "url_resolver: #{action.route_options.url_resolver}"
                    end

                    ActionButton(action, url:, variant: :table)
                  end
              end
            end
          end
        end

        def render_footer
          div(class: "lg:sticky lg:dyna:static bottom-[-2px] mt-1 p-4 pb-6 w-full z-30 bg-gray-50 dark:bg-gray-900") {
            TableInfo(pagy_instance)
            TablePagination(pagy_instance)
          }
        end
      end
    end
  end
end

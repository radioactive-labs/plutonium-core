# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # Custom selection column with Stimulus data attributes for bulk actions
        class SelectionColumn < Phlexi::Table::Components::SelectionColumn
          def header_cell
            SelectionHeaderCell.new
          end

          def data_cell(wrapped_object)
            allowed_actions = compute_allowed_actions(wrapped_object.unwrapped)
            SelectionDataCell.new(wrapped_object.field(key).dom.value, allowed_actions)
          end

          # Add hidden class and Stimulus target to header cell
          def header_cell_attributes
            {
              class: "hidden w-12",
              data: {bulk_actions_target: "selectionCell"}
            }
          end

          # Add hidden class and Stimulus target to data cell
          def data_cell_attributes(wrapped_object)
            {
              scope: :row,
              class: "hidden",
              data: {bulk_actions_target: "selectionCell"}
            }
          end

          private

          def bulk_actions
            options[:bulk_actions] || []
          end

          def policy_resolver
            options[:policy_resolver]
          end

          def compute_allowed_actions(record)
            return bulk_action_names unless policy_resolver

            policy = policy_resolver.call(record)
            bulk_actions.select { |action|
              policy.allowed_to?(:"#{action.name}?")
            }.map { |a| a.name.to_s }
          end
        end

        # Header cell checkbox with "select all" functionality
        class SelectionHeaderCell < Phlexi::Table::HTML
          def view_template
            input(
              type: :checkbox,
              class: themed(:selection_checkbox),
              data: {
                bulk_actions_target: "checkboxAll",
                action: "bulk-actions#toggleAll"
              }
            )
          end
        end

        # Data cell checkbox for individual row selection
        class SelectionDataCell < Phlexi::Table::HTML
          def initialize(value, allowed_actions)
            @value = value
            @allowed_actions = allowed_actions
          end

          def view_template
            if @allowed_actions.empty?
              # Show X when no actions available for this record
              span(
                class: "inline-flex items-center justify-center size-4 text-[var(--pu-text-subtle)]",
                title: "No bulk actions available"
              ) { "✕" }
            else
              input(
                type: :checkbox,
                value: @value,
                class: themed(:selection_checkbox),
                data: {
                  bulk_actions_target: "checkbox",
                  action: "bulk-actions#toggle",
                  allowed_actions: @allowed_actions.join(",")
                }
              )
            end
          end
        end
      end
    end
  end
end

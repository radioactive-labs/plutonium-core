# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class KeyValueStore < Phlexi::Form::Components::Base
          include Phlexi::Form::Components::Concerns::HandlesInput

          DEFAULT_LIMIT = 10

          def view_template
            div(**container_attributes) do
              render_key_value_pairs
              render_add_button
              render_template
            end
          end

          protected

          def build_attributes
            super
            attributes[:class] = [attributes[:class], "key-value-store"].compact.join(" ")
            set_data_attributes
          end

          private

          def container_attributes
            {
              id: attributes[:id],
              class: attributes[:class],
              data: {
                controller: "key-value-store",
                key_value_store_limit_value: limit
              }
            }
          end

          def set_data_attributes
            attributes[:data] ||= {}
            attributes[:data][:controller] = "key-value-store"
            attributes[:data][:key_value_store_limit_value] = limit
          end

          def render_header
            div(class: "key-value-store-header") do
              if attributes[:label]
                h3(class: "text-lg font-semibold text-gray-900 dark:text-white") do
                  plain attributes[:label]
                end
              end
              if attributes[:description]
                p(class: "text-sm text-gray-500 dark:text-gray-400") do
                  plain attributes[:description]
                end
              end
            end
          end

          def render_key_value_pairs
            div(class: "key-value-pairs space-y-sm", data_key_value_store_target: "container") do
              pairs.each_with_index do |(key, value), index|
                render_key_value_pair(key, value, index)
              end
            end
          end

          def render_key_value_pair(key, value, index)
            div(
              class: "key-value-pair flex items-center gap-sm p-sm border border-gray-200 dark:border-gray-700 rounded",
              data_key_value_store_target: "pair"
            ) do
              # Key input
              input(
                type: :text,
                placeholder: "Key",
                value: key,
                name: "#{field_name}[#{index}][key]",
                id: "#{field.dom.id}_#{index}_key",
                class: "flex-1 px-sm py-xs text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white",
                data_key_value_store_target: "keyInput"
              )

              # Value input
              input(
                type: :text,
                placeholder: "Value",
                value: value,
                name: "#{field_name}[#{index}][value]",
                id: "#{field.dom.id}_#{index}_value",
                class: "flex-1 px-sm py-xs text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white",
                data_key_value_store_target: "valueInput"
              )

              # Remove button
              button(
                type: :button,
                class: "px-sm py-xs text-red-600 hover:text-red-800 focus:outline-none",
                data_action: "key-value-store#removePair"
              ) do
                plain "×"
              end
            end
          end

          def render_add_button
            div(class: "key-value-store-actions mt-sm") do
              button(
                type: :button,
                id: "#{field.dom.id}_add_button",
                class: "inline-flex items-center px-sm py-xs text-sm font-medium text-blue-600 bg-blue-50 border border-blue-200 rounded hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-blue-900 dark:text-blue-300 dark:border-blue-700 dark:hover:bg-blue-800",
                data: {
                  action: "key-value-store#addPair",
                  key_value_store_target: "addButton"
                }
              ) do
                plain "+ Add Pair"
              end
            end
          end

          def render_template
            template(data_key_value_store_target: "template") do
              div(
                class: "key-value-pair flex items-center gap-sm p-sm border border-gray-200 dark:border-gray-700 rounded",
                data_key_value_store_target: "pair"
              ) do
                input(
                  type: :text,
                  placeholder: "Key",
                  name: "#{field_name}[__INDEX__][key]",
                  id: "#{field.dom.id}___INDEX___key",
                  class: "flex-1 px-sm py-xs text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white",
                  data_key_value_store_target: "keyInput"
                )

                input(
                  type: :text,
                  placeholder: "Value",
                  name: "#{field_name}[__INDEX__][value]",
                  id: "#{field.dom.id}___INDEX___value",
                  class: "flex-1 px-sm py-xs text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white",
                  data_key_value_store_target: "valueInput"
                )

                button(
                  type: :button,
                  class: "px-sm py-xs text-red-600 hover:text-red-800 focus:outline-none",
                  data_action: "key-value-store#removePair"
                ) do
                  plain "×"
                end
              end
            end
          end

          def pairs
            @pairs ||= normalize_value_to_pairs(field.value)
          end

          def normalize_value_to_pairs(value)
            case value
            when Hash
              # Convert hash to array of [key, value] pairs
              value.to_a
            when String
              parse_json_string(value)
            else
              []
            end
          end

          def parse_json_string(value)
            return [] if value.blank?

            begin
              parsed = JSON.parse(value)
              case parsed
              when Hash
                parsed.to_a
              else
                []
              end
            rescue JSON::ParserError
              []
            end
          end

          def field_name
            field.dom.name
          end

          def limit
            attributes.fetch(:limit, DEFAULT_LIMIT)
          end

          # Override from ExtractsInput concern to normalize form parameters
          def normalize_input(input_value)
            case input_value
            when Hash
              if input_value.keys.all? { |k| k.to_s.match?(/^\d+$/) }
                # Handle indexed form params: {"0" => {"key" => "foo", "value" => "bar"}}
                process_indexed_params(input_value)
              else
                # Handle direct hash params
                input_value.reject { |k, v| k.blank? || (v.blank? && v != false) }
              end
            when nil
              {}
            end
          end

          private

          # Process indexed form parameters into a hash
          def process_indexed_params(params)
            params.values.each_with_object({}) do |pair, hash|
              next unless pair.is_a?(Hash)

              key = pair["key"] || pair[:key]
              value = pair["value"] || pair[:value]

              if key.present?
                hash[key] = value
              end
            end
          end
        end
      end
    end
  end
end

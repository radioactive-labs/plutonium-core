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

          def render_key_value_pairs
            # Hidden sentinel input ensures the field is always present in params when the
            # component is rendered. Without this, removing all pairs would submit nothing,
            # making it impossible to distinguish "field not in form" from "field cleared".
            # This allows normalize_input to return nil (preserve existing) vs {} (clear field).
            input(type: :hidden, name: "#{field_name}[_submitted]", value: "1", autocomplete: "off", hidden: true)

            div(class: "key-value-pairs space-y-2", data_key_value_store_target: "container") do
              pairs.each_with_index do |(key, value), index|
                render_key_value_pair(key, value, index)
              end
            end
          end

          def render_key_value_pair(key, value, index)
            div(
              class: "key-value-pair flex items-center gap-2",
              data_key_value_store_target: "pair"
            ) do
              render_pair_input(:key, key, index)
              render_pair_input(:value, value, index)

              button(
                type: :button,
                class: "pu-btn pu-btn-sm pu-btn-ghost text-danger-600 dark:text-danger-400",
                aria_label: Plutonium::Translation.t("plutonium.ui.form.key_value_store.remove_pair"),
                data_action: "key-value-store#removePair"
              ) do
                render Phlex::TablerIcons::X.new(class: "w-4 h-4")
              end
            end
          end

          # `part` is :key or :value. The template row passes "__INDEX__", which
          # the controller swaps for the real index when it clones the row.
          def render_pair_input(part, value, index)
            input(
              type: :text,
              placeholder: Plutonium::Translation.t("plutonium.ui.form.key_value_store.#{part}_placeholder"),
              value:,
              name: "#{field_name}[#{index}][#{part}]",
              id: "#{field.dom.id}_#{index}_#{part}",
              class: "pu-input flex-1 min-w-0",
              data_key_value_store_target: "#{part}Input"
            )
          end

          def render_add_button
            div(class: "key-value-store-actions mt-2") do
              button(
                type: :button,
                id: "#{field.dom.id}_add_button",
                class: "pu-btn pu-btn-sm pu-btn-soft-primary",
                data: {
                  action: "key-value-store#addPair",
                  key_value_store_target: "addButton"
                }
              ) do
                plain Plutonium::Translation.t("plutonium.ui.form.key_value_store.add_pair")
              end
            end
          end

          def render_template
            template(data_key_value_store_target: "template") do
              render_key_value_pair(nil, nil, "__INDEX__")
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

          # Override from ExtractsInput concern to normalize form parameters.
          # Returns nil if field wasn't submitted (preserves existing value),
          # or a Hash (possibly empty) if the field was in the form.
          def normalize_input(input_value)
            case input_value
            when Hash
              # Remove the sentinel key before processing
              params = input_value.except("_submitted", :_submitted)

              if params.keys.all? { |k| k.to_s.match?(/^\d+$/) }
                # Handle indexed form params: {"0" => {"key" => "foo", "value" => "bar"}}
                process_indexed_params(params)
              else
                # Handle direct hash params
                params.reject { |k, v| k.blank? || (v.blank? && v != false) }
              end
            when nil
              # Field was not submitted at all - preserve existing value
              nil
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

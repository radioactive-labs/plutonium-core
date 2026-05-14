# frozen_string_literal: true

require "json"

module Plutonium
  module UI
    module Form
      module Components
        # Textarea-based input for `json` / `jsonb` columns.
        #
        # On render, serializes Hash/Array values to pretty JSON so users see
        # valid JSON instead of Ruby `Hash#to_s` output (e.g. `{:k=>"v"}`).
        # Strings are pretty-formatted if parseable, passed through verbatim
        # otherwise — preserves an in-progress edit on form re-render.
        #
        # On submit, accepts either a JSON string (typed input) or a raw
        # Hash/Array (e.g. a JSON-bodied API request that Rails has already
        # parsed into params). Unparseable strings are passed through so model
        # validation can surface the error, rather than being silently dropped.
        class Json < Phlexi::Form::Components::Textarea
          def view_template
            textarea(**attributes) { serialized_value }
          end

          protected

          def serialized_value
            case (raw = field.value)
            when nil then ""
            when String then format_string(raw)
            else JSON.pretty_generate(raw)
            end
          end

          def format_string(str)
            JSON.pretty_generate(JSON.parse(str))
          rescue JSON::ParserError
            str
          end

          def normalize_input(input_value)
            case input_value
            when nil then nil
            when Hash, Array then input_value
            when "" then nil
            else
              begin
                JSON.parse(input_value)
              rescue JSON::ParserError
                input_value
              end
            end
          end
        end
      end
    end
  end
end

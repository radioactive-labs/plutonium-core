# frozen_string_literal: true

require "test_helper"

# The fixed words filters wrap around their derived label live in
# config/locales/en/resource.yml (plutonium.query.*).
module Plutonium
  module Query
    module Filters
      class PlaceholderI18nTest < Minitest::Test
        def test_text_placeholders_interpolate_the_label
          assert_equal "Title", placeholder(Text.new(key: :title), :query)
          assert_equal "Title (use * as wildcard)", placeholder(Text.new(key: :title, predicate: :matches), :query)
          assert_equal "Title (use * as wildcard)", placeholder(Text.new(key: :title, predicate: :not_matches), :query)
          assert_equal "Title starts with...", placeholder(Text.new(key: :title, predicate: :starts_with), :query)
          assert_equal "Title ends with...", placeholder(Text.new(key: :title, predicate: :ends_with), :query)
          assert_equal "Title contains...", placeholder(Text.new(key: :title, predicate: :contains), :query)
          assert_equal "Title contains...", placeholder(Text.new(key: :title, predicate: :not_contains), :query)
        end

        def test_date_placeholders_interpolate_the_label
          assert_equal "Due date", placeholder(Date.new(key: :due_date), :value)
          assert_equal "Due date not on...", placeholder(Date.new(key: :due_date, predicate: :not_eq), :value)
          assert_equal "Due date before...", placeholder(Date.new(key: :due_date, predicate: :lt), :value)
          assert_equal "Due date on or before...", placeholder(Date.new(key: :due_date, predicate: :lteq), :value)
          assert_equal "Due date after...", placeholder(Date.new(key: :due_date, predicate: :gt), :value)
          assert_equal "Due date on or after...", placeholder(Date.new(key: :due_date, predicate: :gteq), :value)
        end

        def test_date_range_placeholders_interpolate_the_label
          filter = DateRange.new(key: :created_at)

          assert_equal "Created at from...", placeholder(filter, :from)
          assert_equal "Created at to...", placeholder(filter, :to)
        end

        def test_boolean_labels_and_blank_option_come_from_the_locale
          options = Boolean.new(key: :active).defined_inputs[:value][:options]

          assert_equal [["Yes", "true"], ["No", "false"]], options[:choices]
          assert_equal "All", options[:include_blank]
          assert_equal "All", Select.new(key: :status, choices: %w[a b]).defined_inputs[:value][:options][:include_blank]
        end

        def test_multi_input_filter_value_label_qualifies_each_input
          query_object = Plutonium::Resource::QueryObject.new(nil, {created_at: {from: "2024", to: "2025"}}, "/things") do |qo|
            qo.define_filter(:created_at, DateRange.new(key: :created_at))
          end

          assert_equal "from 2024, to 2025", query_object.active_filter_descriptions.first[:value_label]
        end

        private

        def placeholder(filter, input)
          filter.defined_inputs # customize_inputs is what declares the placeholder field
          filter.defined_fields[input][:options][:placeholder]
        end
      end
    end
  end
end

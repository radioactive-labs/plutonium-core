# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    class FilterTest < Minitest::Test
      # ==================== Lookup Tests ====================

      def test_lookup_text_filter
        klass = Filter.lookup(:text)

        assert_equal Plutonium::Query::Filters::Text, klass
      end

      def test_lookup_select_filter
        klass = Filter.lookup(:select)

        assert_equal Plutonium::Query::Filters::Select, klass
      end

      def test_lookup_boolean_filter
        klass = Filter.lookup(:boolean)

        assert_equal Plutonium::Query::Filters::Boolean, klass
      end

      def test_lookup_date_filter
        klass = Filter.lookup(:date)

        assert_equal Plutonium::Query::Filters::Date, klass
      end

      def test_lookup_date_range_filter
        klass = Filter.lookup(:date_range)

        assert_equal Plutonium::Query::Filters::DateRange, klass
      end

      def test_lookup_association_filter
        klass = Filter.lookup(:association)

        assert_equal Plutonium::Query::Filters::Association, klass
      end

      def test_lookup_with_filter_class_returns_same_class
        klass = Filter.lookup(Plutonium::Query::Filters::Text)

        assert_equal Plutonium::Query::Filters::Text, klass
      end

      def test_lookup_with_unknown_type_raises_error
        error = assert_raises(ArgumentError) do
          Filter.lookup(:unknown_filter_type)
        end

        assert_match(/Unknown filter type/, error.message)
        assert_match(/unknown_filter_type/, error.message)
      end

      def test_lookup_with_camelcase_type
        klass = Filter.lookup(:date_range)

        assert_equal Plutonium::Query::Filters::DateRange, klass
      end
    end
  end
end

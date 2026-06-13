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

      # ==================== resource_class Tests ====================
      #
      # The query bridge (Queryable#current_query_object) injects resource_class
      # into *every* filter it builds. The base must accept and expose it, and the
      # forwarding filters (Text/Select/DateRange/...) — which splat **opts into
      # super — must not raise on it. Otherwise injecting resource_class universally
      # breaks every non-association filter.

      def test_base_accepts_and_exposes_resource_class
        filter = Filter.new(key: :name, resource_class: :some_resource)

        assert_equal :some_resource, filter.resource_class
      end

      def test_resource_class_defaults_to_nil
        filter = Filter.new(key: :name)

        assert_nil filter.resource_class
      end

      def test_forwarding_filters_accept_resource_class
        # Each of these splats ** into super; the base must absorb resource_class.
        [
          Filters::Text.new(key: :name, resource_class: :r),
          Filters::Select.new(key: :status, resource_class: :r),
          Filters::DateRange.new(key: :created_at, resource_class: :r),
          Filters::Date.new(key: :created_at, resource_class: :r),
          Filters::Boolean.new(key: :active, resource_class: :r)
        ].each do |filter|
          assert_equal :r, filter.resource_class, "#{filter.class} dropped resource_class"
        end
      end
    end
  end
end

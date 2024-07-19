require "test_helper"

module Plutonium
  module Lib
    class OverlayedHashTest < Minitest::Test
      def setup
        @base = {a: 1, b: 2, c: 3}
        @overlayed_hash = OverlayedHash.new(@base)
      end

      def test_initialization
        assert_equal 1, @overlayed_hash[:a]
        assert_equal 2, @overlayed_hash[:b]
        assert_equal 3, @overlayed_hash[:c]
      end

      def test_get_value
        assert_equal 1, @overlayed_hash[:a]
        assert_nil @overlayed_hash[:d]
      end

      def test_set_value
        @overlayed_hash[:b] = 4
        @overlayed_hash[:d] = 5

        assert_equal 4, @overlayed_hash[:b]
        assert_equal 5, @overlayed_hash[:d]
        assert_equal 2, @base[:b]
        assert_nil @base[:d]
      end

      def test_key_exists
        assert @overlayed_hash.key?(:a)
        assert @overlayed_hash.key?(:b)
        refute @overlayed_hash.key?(:d)

        @overlayed_hash[:d] = 5
        assert @overlayed_hash.key?(:d)
      end

      def test_each_key
        keys = []
        @overlayed_hash.each_key { |key| keys << key }
        assert_equal [:a, :b, :c], keys.sort

        @overlayed_hash[:d] = 5
        keys = []
        @overlayed_hash.each_key { |key| keys << key }
        assert_equal [:a, :b, :c, :d], keys.sort
      end

      def test_keys
        assert_equal [:a, :b, :c], @overlayed_hash.keys.sort

        @overlayed_hash[:d] = 5
        assert_equal [:a, :b, :c, :d], @overlayed_hash.keys.sort
      end

      def test_values
        assert_equal [1, 2, 3], @overlayed_hash.values.sort

        @overlayed_hash[:b] = 4
        @overlayed_hash[:d] = 5
        assert_equal [1, 3, 4, 5], @overlayed_hash.values.sort
      end

      def test_to_h
        assert_equal({a: 1, b: 2, c: 3}, @overlayed_hash.to_h)

        @overlayed_hash[:b] = 4
        @overlayed_hash[:d] = 5
        assert_equal({a: 1, b: 4, c: 3, d: 5}, @overlayed_hash.to_h)
      end

      def test_enumerable
        assert_kind_of Enumerator, @overlayed_hash.each_key
      end

      def test_base_hash_unchanged
        @overlayed_hash[:b] = 4
        @overlayed_hash[:d] = 5

        assert_equal({a: 1, b: 2, c: 3}, @base)
      end
    end
  end
end

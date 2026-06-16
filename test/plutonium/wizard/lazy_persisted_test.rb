# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    class LazyPersistedTest < ActiveSupport::TestCase
      setup do
        Organization.delete_all if defined?(Organization)
        @org = Organization.create!(name: "Lazy")
        @gid = @org.to_global_id.to_s
      end

      def counting_locates
        count = 0
        original = GlobalID::Locator.method(:locate)
        GlobalID::Locator.define_singleton_method(:locate) do |*args, **kw|
          count += 1
          original.call(*args, **kw)
        end
        yield
        count
      ensure
        GlobalID::Locator.singleton_class.send(:remove_method, :locate)
        GlobalID::Locator.define_singleton_method(:locate, original)
      end

      test "empty source: untouched key returns [] and never locates" do
        lp = LazyPersisted.new
        assert_equal 0, counting_locates { assert_equal [], lp[:nope] }
      end

      test "stored GIDs are located lazily on first read, then memoized" do
        lp = LazyPersisted.new("make" => [@gid])

        first = counting_locates { assert_equal [@org], lp[:make] }
        assert_equal 1, first

        second = counting_locates { assert_equal [@org], lp[:make] }
        assert_equal 0, second
      end

      test "string and symbol keys resolve the same stored entry" do
        lp = LazyPersisted.new("make" => [@gid])
        assert_equal [@org], lp["make"]
        assert_equal [@org], lp[:make]
      end

      test "set records are returned without locating and shadow stored GIDs" do
        lp = LazyPersisted.new("make" => [@gid])
        other = Organization.create!(name: "Live")
        lp[:make] = [other]
        assert_equal 0, counting_locates { assert_equal [other], lp[:make] }
      end

      test "key? is true for memoized and stored keys without locating" do
        lp = LazyPersisted.new("make" => [@gid])
        assert_equal 0, counting_locates {
          assert lp.key?(:make)
          assert lp.key?("make")
          refute lp.key?(:other)
        }
        lp[:other] = [@org]
        assert lp.key?(:other)
      end

      test "keys lists memoized and stored keys as symbols without locating" do
        lp = LazyPersisted.new("make" => [@gid])
        lp[:extra] = []
        assert_equal 0, counting_locates {
          assert_equal %i[make extra].sort, lp.keys.sort
        }
      end

      test "to_h resolves every known key" do
        lp = LazyPersisted.new("make" => [@gid])
        assert_equal({make: [@org]}, lp.to_h)
      end
    end
  end
end

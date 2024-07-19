require "test_helper"

module Plutonium
  module Lib
    class BitFlagsTest < Minitest::Test
      def setup
        @flags = BitFlags.new(:read, "write", :execute)
      end

      def test_initialization
        assert_equal [:read, :write, :execute], @flags.flags
        assert_equal [1, 2, 4], @flags.indices
      end

      def test_set_with_single_flag
        assert @flags.set?(1, :read)
        assert @flags.set?(2, "write")
        assert @flags.set?(4, :execute)
      end

      def test_set_with_multiple_flags
        assert @flags.set?(3, :read, "write")
        assert @flags.set?(6, "write", :execute)
        assert @flags.set?(7, :read, "write", :execute)
      end

      def test_set_with_unset_flags
        refute @flags.set?(1, "write")
        refute @flags.set?(2, :read)
        refute @flags.set?(3, :execute)
      end

      def test_extract_flags
        assert_equal [:read], @flags.extract(1)
        assert_equal [:write], @flags.extract(2)
        assert_equal [:read, :write], @flags.extract(3)
        assert_equal [:read, :write, :execute], @flags.extract(7)
      end

      def test_extract_with_no_flags_set
        assert_empty @flags.extract(0)
      end

      def test_bracket_operator
        assert_equal 1, @flags[:read]
        assert_equal 2, @flags["write"]
        assert_equal 4, @flags[:execute]
        assert_equal 3, @flags[:read, "write"]
        assert_equal 7, @flags["read", :write, "execute"]
      end

      def test_bits_method
        assert_equal 1, @flags.bits(:read)
        assert_equal 2, @flags.bits("write")
        assert_equal 4, @flags.bits(:execute)
        assert_equal 3, @flags.bits(:read, "write")
        assert_equal 7, @flags.bits("read", :write, "execute")
      end

      def test_bits_with_invalid_flag
        assert_equal 3, @flags.bits(:read, "write", :invalid_flag)
      end

      def test_sum_method
        assert_equal 7, @flags.sum
      end

      def test_immutability
        assert_raises(FrozenError) { @flags.flags << :delete }
        assert_raises(FrozenError) { @flags.indices << 8 }
      end

      def test_large_number_of_flags
        size = 100
        flags = (1..size).map { |i| i.even? ? "flag_#{i}" : :"flag_#{i}" }
        large_flags = BitFlags.new(*flags)
        assert_equal size, large_flags.flags.size
        assert_equal (2**size - 1), large_flags.sum
      end

      def test_no_flags
        empty_flags = BitFlags.new
        assert_empty empty_flags.flags
        assert_empty empty_flags.indices
        assert_equal 0, empty_flags.sum
      end

      def test_duplicate_flags
        duplicate_flags = BitFlags.new(:read, "write", :read, "read")
        assert_equal [:read, :write], duplicate_flags.flags
        assert_equal [1, 2], duplicate_flags.indices
        assert_equal 3, duplicate_flags.sum
      end

      def test_duplicate_flags_order
        duplicate_flags = BitFlags.new("write", :read, "write")
        assert_equal [:write, :read], duplicate_flags.flags
        assert_equal [1, 2], duplicate_flags.indices
        assert_equal 3, duplicate_flags.sum
      end

      def test_set_with_invalid_flag
        refute @flags.set?(7, :invalid_flag)
        refute @flags.set?(7, "read", :invalid_flag)
        assert @flags.set?(7, :read, "write", :execute)
      end

      def test_set_with_mixed_valid_and_invalid_flags
        refute @flags.set?(3, :read, "invalid_flag")
        refute @flags.set?(7, "read", :write, "execute", :invalid_flag)
      end

      def test_extract_with_value_exceeding_all_flags
        assert_equal [:read, :write, :execute], @flags.extract(15)
      end

      def test_symbol_and_string_equivalence
        assert_equal @flags[:read], @flags["read"]
        assert_equal @flags.bits(:write), @flags.bits("write")
        assert @flags.set?(3, :read, "write")
        assert @flags.set?(3, "read", :write)
      end
    end
  end
end

module Plutonium
  module Lib
    # The BitFlags class provides a convenient way to work with bit flags.
    # It allows setting, checking, and extracting flags using a more
    # readable interface. It supports both symbols and strings as flags.
    #
    # @example Usage
    #   flags = BitFlags.new(:read, 'write', :execute)
    #   value = flags[:read, 'write']  # => 3
    #   flags.set?(value, :read)       # => true
    #   flags.set?(value, 'execute')   # => false
    #   flags.extract(value)           # => [:read, :write]
    #
    class BitFlags
      # @return [Array<Symbol>] An array of all defined flags.
      attr_reader :flags

      # @return [Array<Integer>] An array of all defined bit values.
      attr_reader :indices

      # Initializes a new BitFlags object with the given flags.
      #
      # @param flags [Array<Symbol, String>] The flags to be used in this BitFlags object.
      # @example
      #   BitFlags.new(:read, 'write', :execute)
      def initialize(*flags)
        @flags = normalize_flags(flags).uniq.freeze
        @indices = @flags.each_index.map { |index| 1 << index }.freeze
        @map = @flags.zip(@indices).to_h.freeze
        @all_bits = calculate_all_bits
      end

      # Checks if the given value has all the specified flags set.
      #
      # @param value [Integer] The value to check against.
      # @param flags [Array<Symbol, String>] The flags to check for.
      # @return [Boolean] True if all specified flags are set and valid, false otherwise.
      # @example
      #   flags.set?(3, :read, 'write')  # => true
      def set?(value, *flags)
        normalized_flags = normalize_flags(flags)
        return false if normalized_flags.any? { |flag| !@map.key?(flag) }
        check = bits(*normalized_flags)
        value & check == check
      end

      # Sets the specified flags in the given value.
      #
      # @param value [Integer] The original value to modify.
      # @param flags [Array<Symbol, String>] The flags to set.
      # @return [Integer] A new value with the specified flags set.
      # @example
      #   flags.set!(2, :read, :execute)  # => 6
      def set!(value, *flags)
        normalized_flags = normalize_flags(flags)
        bits_to_set = bits(*normalized_flags)
        value | bits_to_set
      end

      # Extracts the flags that are set in the given value.
      #
      # @param value [Integer] The value to extract flags from.
      # @return [Array<Symbol>] An array of flags that are set in the value.
      # @example
      #   flags.extract(3)  # => [:read, :write]
      def extract(value)
        value &= @all_bits
        @map.select { |_, bit| value & bit != 0 }.keys
      end

      # Returns the bit value for the given flags.
      #
      # @param flags [Array<Symbol, String>] The flags to get the bit value for.
      # @return [Integer] The combined bit value of the given flags.
      # @example
      #   flags[:read, 'write']  # => 3
      def [](*flags)
        bits(*flags)
      end

      # Calculates the combined bit value for the given flags.
      #
      # @param flags [Array<Symbol, String>] The flags to calculate the bit value for.
      # @return [Integer] The combined bit value of the given flags.
      # @example
      #   flags.bits(:read, 'write')  # => 3
      def bits(*flags)
        normalized_flags = normalize_flags(flags)
        normalized_flags.sum { |flag| @map[flag] || 0 }
      end

      # Calculates the sum of all bit values.
      #
      # @return [Integer] The sum of all bit values.
      def sum
        @all_bits
      end

      private

      def calculate_all_bits
        @indices.inject(:|) || 0
      end

      def normalize_flags(flags)
        flags.map(&:to_sym)
      end
    end
  end
end

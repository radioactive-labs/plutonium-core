module Plutonium
  module Lib
    class BitFlags
      delegate :sum, to: :indices

      def initialize(*flags)
        @map = flags.each_with_index.map { |flag, index| [flag, 2.pow(index)] }.to_h
      end

      def set?(value, *flags)
        check = bits(*flags)
        value & check == check
      end

      def extract(value)
        @map.select { |_flag, bit| value & bit == bit }.keys
      end

      def [](*flags)
        bits(*flags)
      end

      def bits(*flags)
        @map.slice(*flags).values.sum
      end

      def flags
        @flags ||= @map.keys
      end

      def indices
        @indices ||= @map.values
      end
    end
  end
end

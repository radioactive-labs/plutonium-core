module Plutonium
  module Builders
    class SidebarMenuItem
      attr_accessor :name, :value
      attr_reader :indicator

      def initialize(name, indicator: nil, value: nil)
        @name = name
        @indicator = indicator
        @value = value
      end

      def url(url)
        @value = url
      end

      def items(&)
        raise ArgumentError, "Indicator not allowed for items with children" if @indicator
        @value = Menu.new(&).items
      end

      def indicator=(indicator)
        raise ArgumentError, "Indicator not allowed for items with children" if @value.is_a?(Array)
        @indicator = indicator
      end
    end
  end
end

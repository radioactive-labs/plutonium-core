module Plutonium
  module Builders
    class SidebarMenu
      attr_reader :items

      def initialize(&block)
        @items = []
        instance_eval(&block)
      end

      def item(name, indicator: nil, url: nil, &block)
        if block && indicator
          raise ArgumentError, "Items with children cannot have an indicator."
        end

        item = SidebarMenuItem.new(name, indicator: indicator)
        if block
          item.items(&block)
        else
          item.url(url)
        end
        @items << item
      end
    end
  end
end

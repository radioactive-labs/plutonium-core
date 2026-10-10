# frozen_string_literal: true

module Plutonium
  module Dashboard
    # A link in the dashboard's toolbar, declared with `link`: the way to a
    # related page such as the dashboard's settings or a full report.
    class Link
      attr_reader :key, :icon

      def initialize(key, href:, label: nil, icon: nil, condition: nil)
        @key = key.to_sym
        @href = href
        @label = label
        @icon = icon
        @condition = condition
      end

      def label
        Plutonium::Translation.resolve(@label) || key.to_s.humanize
      end

      # Evaluated like a card's `href:`: a proc runs on the dashboard instance.
      def href_for(dashboard)
        @href.is_a?(Proc) ? dashboard.instance_exec(&@href) : @href
      end

      # Like a card's `condition:`: a proc on the instance or a method name.
      def visible?(dashboard)
        case @condition
        when nil then true
        when Symbol then dashboard.send(@condition) ? true : false
        when Proc then dashboard.instance_exec(&@condition) ? true : false
        else @condition ? true : false
        end
      end
    end
  end
end

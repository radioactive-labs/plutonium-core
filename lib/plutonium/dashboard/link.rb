# frozen_string_literal: true

module Plutonium
  module Dashboard
    # A link in the dashboard's toolbar, declared with `link`: the way to a
    # related page such as the dashboard's settings or a full report.
    class Link
      include Evaluation

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

      # Evaluated like a card's `href:`.
      def href_for(dashboard)
        @href.is_a?(Proc) ? evaluate_on(dashboard, @href) : @href
      end

      # Evaluated like a card's `condition:`.
      def visible?(dashboard)
        condition_passes?(dashboard, @condition)
      end
    end
  end
end

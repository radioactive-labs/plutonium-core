# frozen_string_literal: true

module Plutonium
  module Dashboard
    # Per-engine registry of the dashboards mounted with `register_dashboard`,
    # so the sidebar can list them in registration order.
    #
    # Classes are stored by name and resolved on read, so a code reload never
    # hands out a stale class object.
    class Register
      def initialize
        @names = []
      end

      # @param dashboard_class [Class] a {Base} subclass
      def register(dashboard_class)
        unless dashboard_class.is_a?(Class) && dashboard_class < Plutonium::Dashboard::Base
          raise ArgumentError, "#{dashboard_class.inspect} must subclass Plutonium::Dashboard::Base"
        end

        @names << dashboard_class.name unless @names.include?(dashboard_class.name)
      end

      # @return [Array<Class>] registered dashboards, in registration order
      def dashboards
        @names.map(&:constantize)
      end

      def registered?(dashboard_class)
        @names.include?(dashboard_class.name)
      end

      def clear
        @names.clear
      end

      def empty? = @names.empty?
    end
  end
end

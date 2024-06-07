require "pundit"

module Plutonium
  module Pundit
    class PolicyFinder < ::Pundit::PolicyFinder
      def initialize(*, package:)
        super(*)
        @package = package
      end

      attr_reader :package

      def policy
        policy_internal([package, object]) || policy_internal(object)
      end

      private

      def policy_internal(object)
        klass = find(object)
        klass.is_a?(String) ? klass.safe_constantize : klass
      end
    end
  end
end

require "pundit"

module Plutonium
  module Pundit
    class Context < ::Pundit::Context
      def initialize(*, package:, **)
        super(*, **)
        @package = package
      end

      private

      def policy_finder(record)
        PolicyFinder.new(record, package: @package)
      end
    end
  end
end

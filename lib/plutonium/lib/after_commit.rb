# frozen_string_literal: true

module Plutonium
  module Lib
    class AfterCommit
      def initialize(rolled_back: false, &block)
        @rolled_back = rolled_back
        @callback = block
      end

      def committed!(*)
        @callback.call
      end

      def before_committed!(*)
      end

      def rolledback!(*)
        @callback.call if @rolled_back
      end

      def trigger_transactional_callbacks?
        true
      end

      class << self
        def execute(rolled_back: false, connection: ActiveRecord::Base.connection, &block)
          connection.transaction_open? ? connection.add_transaction_record(AfterCommit.new(rolled_back: rolled_back, &block)) : yield
          nil
        end
      end
    end
  end
end

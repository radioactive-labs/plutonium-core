# frozen_string_literal: true

module Plutonium
  module Testing
    module ResourceInteraction
      extend ActiveSupport::Concern

      class MockViewContext
        def controller = @controller ||= MockController.new

        class MockController
          def helpers = @helpers ||= MockHelpers.new

          class MockHelpers
            def current_user = nil
          end
        end
      end

      def assert_interaction_success(klass, **input)
        outcome = build_interaction(klass, **input).call
        assert outcome.success?, "Expected #{klass} to succeed, got #{outcome.inspect}"
        outcome
      end

      def assert_interaction_failure(klass, **input)
        outcome = build_interaction(klass, **input).call
        assert outcome.failure?, "Expected #{klass} to fail, got #{outcome.inspect}"
        outcome
      end

      def interaction_view_context
        MockViewContext.new
      end

      def interaction_class
        raise NotImplementedError, "Override #interaction_class to return the interaction under test"
      end

      def valid_interaction_input
        raise NotImplementedError, "Override #valid_interaction_input to return a Hash of valid input"
      end

      private

      def build_interaction(klass, **input)
        klass.new(view_context: interaction_view_context, **input)
      end
    end
  end
end

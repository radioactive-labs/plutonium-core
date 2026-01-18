require "test_helper"

module Plutonium
  module Interaction
    class BaseTest < Minitest::Test
      class MockViewContext
        def controller
          @controller ||= MockController.new
        end

        class MockController
          def helpers
            @helpers ||= MockHelpers.new
          end

          class MockHelpers
            def current_user
              nil
            end
          end
        end
      end

      class TestInteraction < Base
        attribute :input, :string
        validates :input, presence: true

        private

        def execute
          succeed("Result: #{input}")
        end
      end

      def mock_view_context
        MockViewContext.new
      end

      def test_call_class_method
        result = TestInteraction.call(view_context: mock_view_context, input: "test")
        assert result.success?
        assert_equal "Result: test", result.value
      end

      def test_call_instance_method_success
        interaction = TestInteraction.new(view_context: mock_view_context, input: "test")
        result = interaction.call
        assert result.success?
        assert_equal "Result: test", result.value
      end

      def test_call_instance_method_failure
        interaction = TestInteraction.new(view_context: mock_view_context, input: "")
        result = interaction.call
        assert result.failure?
      end

      def test_execute_not_implemented
        interaction_class = Class.new(Base)
        interaction = interaction_class.new(view_context: mock_view_context)
        assert_raises(NotImplementedError) { interaction.call }
      end
    end
  end
end

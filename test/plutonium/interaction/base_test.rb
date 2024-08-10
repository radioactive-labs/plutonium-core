require "test_helper"

module Plutonium
  module Interaction
    class BaseTest < Minitest::Test
      class TestInteraction < Base
        attribute :input, :string
        validates :input, presence: true

        private

        def execute
          success("Result: #{input}")
        end
      end

      def test_call_class_method
        result = TestInteraction.call(input: "test")
        assert result.success?
        assert_equal "Result: test", result.value
      end

      def test_call_instance_method_success
        interaction = TestInteraction.new(input: "test")
        result = interaction.call
        assert result.success?
        assert_equal "Result: test", result.value
      end

      def test_call_instance_method_failure
        interaction = TestInteraction.new(input: "")
        result = interaction.call
        assert result.failure?
        assert result.errors.any?
      end

      def test_execute_not_implemented
        interaction = Class.new(Base).new
        assert_raises(NotImplementedError) { interaction.call }
      end
    end
  end
end

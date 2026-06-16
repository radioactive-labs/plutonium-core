# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    class ConfigurationTest < Minitest::Test
      def test_default_values
        config = Plutonium::Wizard::Configuration.new

        assert_equal false, config.enabled
        assert_equal 14.days, config.cleanup_after
        assert_equal :primary, config.database
      end

      def test_exposed_via_plutonium_configuration
        wizards = Plutonium.configuration.wizards

        assert_instance_of Plutonium::Wizard::Configuration, wizards
        # NOTE: the dummy app enables wizards in its initializer so the sessions
        # table migrates for the AR-store tests; the +enabled+ default itself is
        # covered by #test_default_values against a fresh Configuration.
        assert_equal 14.days, wizards.cleanup_after
        assert_equal :primary, wizards.database
      end

      def test_not_anchored_error_is_a_standard_error
        assert_operator Plutonium::Wizard::NotAnchoredError, :<, StandardError
      end

      def test_step_error_is_a_standard_error
        assert_operator Plutonium::Wizard::StepError, :<, StandardError
      end

      def test_step_error_attribute_defaults_to_base
        error = Plutonium::Wizard::StepError.new("boom")

        assert_equal :base, error.attribute
        assert_equal "boom", error.message
      end

      def test_step_error_attribute_override
        error = Plutonium::Wizard::StepError.new("boom", attribute: :name)

        assert_equal :name, error.attribute
      end
    end
  end
end

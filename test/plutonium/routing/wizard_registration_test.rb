# frozen_string_literal: true

require "test_helper"

# The wizard subsystem is opt-in (`config.wizards.enabled`). When disabled,
# `register_wizard` draws no routes and skips validation entirely — verified here
# against a wizard that WOULD raise when enabled.
class Plutonium::Routing::WizardRegistrationTest < Minitest::Test
  # A `with:`-anchored wizard → `register_wizard` rejects it ("not mounted
  # portal-level") WHEN enabled, so it's a clean probe for the disabled no-op.
  class WithAnchoredWizard < Plutonium::Wizard::Base
    anchored with: Organization
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed(anchor)
  end

  def mapper = Object.new.extend(Plutonium::Routing::WizardRegistration)

  def setup
    @was_enabled = Plutonium.configuration.wizards.enabled
  end

  def teardown
    Plutonium.configuration.wizards.enabled = @was_enabled
  end

  def test_register_wizard_is_a_noop_when_disabled
    Plutonium.configuration.wizards.enabled = false
    # No raise (it would otherwise reject the `with:`-anchored wizard); nothing drawn.
    assert_nil mapper.register_wizard(WithAnchoredWizard, at: "x")
  end

  def test_register_wizard_validates_and_draws_when_enabled
    Plutonium.configuration.wizards.enabled = true
    assert_raises(ArgumentError) { mapper.register_wizard(WithAnchoredWizard, at: "x") }
  end
end

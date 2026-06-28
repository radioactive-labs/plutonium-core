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

  # A guest (public) wizard, for the public-mount dedup/clash tests.
  class AnonWizard < Plutonium::Wizard::Base
    anonymous
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed
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

  # C13: two DIFFERENT public wizards sharing a mount (helper name) must raise a
  # clear error, not silently drop the second. We pre-seed the registry with a
  # different class at the same helper so the clash is detected before any route
  # is appended to the global app route set.
  def test_two_public_wizards_sharing_a_mount_raise
    Plutonium.configuration.wizards.enabled = true
    saved = Plutonium::Routing::WizardRegistration.appended_public_wizards
    Plutonium::Routing::WizardRegistration.appended_public_wizards = {"Some::OtherWizard" => "shared"}
    begin
      err = assert_raises(ArgumentError) { mapper.register_wizard(AnonWizard, at: "shared") }
      assert_match(/already used by Some::OtherWizard/, err.message)
    ensure
      Plutonium::Routing::WizardRegistration.appended_public_wizards = saved
    end
  end

  # `layout:` is a Rails layout NAME (like the controller `layout` macro), passed
  # through as the `wizard_layout` route default; omitted, it's absent so the driving
  # layer defaults it by host.
  def test_layout_rides_the_route_defaults
    assert_equal "basic", mapper.send(:wizard_route_defaults, AnonWizard, :basic)[:wizard_layout]
    assert_nil mapper.send(:wizard_route_defaults, AnonWizard, nil)[:wizard_layout]
  end

  # C13: re-registering the SAME public wizard (boot/reload/multiple portals) is a
  # no-op — no duplicate append, no clash.
  def test_re_registering_the_same_public_wizard_is_a_noop
    Plutonium.configuration.wizards.enabled = true
    saved = Plutonium::Routing::WizardRegistration.appended_public_wizards
    Plutonium::Routing::WizardRegistration.appended_public_wizards = {AnonWizard.name => "shared"}
    begin
      assert_nil mapper.register_wizard(AnonWizard, at: "shared")
    ensure
      Plutonium::Routing::WizardRegistration.appended_public_wizards = saved
    end
  end
end

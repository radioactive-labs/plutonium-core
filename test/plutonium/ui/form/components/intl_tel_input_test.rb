# frozen_string_literal: true

require "test_helper"

# Unit tests for the IntlTelInput component's option extraction. The library
# supports options like initialCountry that Plutonium must forward to the
# Stimulus controller (via a data value) rather than leak onto the <input>.
class Plutonium::UI::Form::Components::IntlTelInputTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Form::Components::IntlTelInput

  def build_options(attrs)
    component = Component.allocate
    component.instance_variable_set(:@attributes, attrs)
    opts = component.send(:build_intl_options)
    [opts, attrs]
  end

  test "initial_country shortcut maps to the library's initialCountry" do
    opts, = build_options({initial_country: "gh"})
    assert_equal({initialCountry: "gh"}, opts)
  end

  test "intl_options hash passes through verbatim (library option names)" do
    opts, = build_options({intl_options: {separateDialCode: true, strictMode: false}})
    assert_equal({separateDialCode: true, strictMode: false}, opts)
  end

  test "initial_country and intl_options merge, with intl_options winning on conflict" do
    opts, = build_options({initial_country: "gh", intl_options: {initialCountry: "ng", separateDialCode: true}})
    assert_equal({initialCountry: "ng", separateDialCode: true}, opts)
  end

  test "no options yields an empty hash" do
    opts, = build_options({})
    assert_equal({}, opts)
  end

  test "the option keys are removed from attributes so they don't render on the input" do
    _opts, attrs = build_options({initial_country: "gh", intl_options: {strictMode: false}, class: "x"})
    refute attrs.key?(:initial_country)
    refute attrs.key?(:intl_options)
    assert attrs.key?(:class), "unrelated attributes are left intact"
  end

  test "falls back to the configured default_phone_country when no country is given" do
    with_default_phone_country("ng") do
      opts, = build_options({})
      assert_equal({initialCountry: "ng"}, opts)
    end
  end

  test "a field-level initial_country overrides the configured default" do
    with_default_phone_country("ng") do
      opts, = build_options({initial_country: "gh"})
      assert_equal({initialCountry: "gh"}, opts)
    end
  end

  private

  def with_default_phone_country(value)
    previous = Plutonium.configuration.default_phone_country
    Plutonium.configuration.default_phone_country = value
    yield
  ensure
    Plutonium.configuration.default_phone_country = previous
  end
end

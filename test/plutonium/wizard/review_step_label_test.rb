# frozen_string_literal: true

require "test_helper"

# The review step's default label is translated (plutonium.wizard.review.label)
# and resolved per call, so it follows the request's locale; an explicit
# `label:` still wins.
class Plutonium::Wizard::ReviewStepLabelTest < ActiveSupport::TestCase
  class DefaultLabel < Plutonium::Wizard::Base
    step(:only) { attribute :name, :string }
    review
    def execute = succeed
  end

  test "review with no label uses the translated default" do
    assert_equal "Review", DefaultLabel.steps.last.label
    assert_equal "Review", Plutonium::Wizard::ReviewStep.new.label
  end

  test "an explicit label wins" do
    assert_equal "Recap", Plutonium::Wizard::ReviewStep.new(label: "Recap").label
  end

  test "the default label follows the locale at call time" do
    available = I18n.available_locales
    I18n.available_locales = available + [:fr]
    I18n.backend.store_translations(:fr, plutonium: {wizard: {review: {label: "Récapitulatif"}}})
    I18n.with_locale(:fr) { assert_equal "Récapitulatif", DefaultLabel.steps.last.label }
    assert_equal "Review", DefaultLabel.steps.last.label
  ensure
    I18n.available_locales = available
  end
end

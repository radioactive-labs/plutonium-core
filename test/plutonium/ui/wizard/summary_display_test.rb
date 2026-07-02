# frozen_string_literal: true

require "test_helper"

# Unit tests for the review summary's choice-label resolution. A choice input
# (select/radio_buttons) stores the raw value in `data`; the value -> label map
# lives only in its `choices:`. The summary resolves it with the same mapper the
# form uses so it reads "Female", not "female".
class Plutonium::UI::Wizard::SummaryDisplayTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Wizard::SummaryDisplay

  # Build a component far enough to call resolve_choice_label: it only reads
  # `object` and the passed input_options.
  def label_for(value, options)
    component = Component.allocate
    component.instance_variable_set(:@object, Struct.new(:sex).new(value))
    component.send(:resolve_choice_label, :sex, options)
  end

  test "resolves [label, value] pairs to the label" do
    choices = [["Male", "male"], ["Female", "female"]]
    assert_equal "Female", label_for("female", choices: choices)
  end

  test "resolves a {value => label} hash to the label" do
    assert_equal "Female", label_for("female", choices: {"male" => "Male", "female" => "Female"})
  end

  test "a flat array (label == value) resolves to itself" do
    assert_equal "female", label_for("female", choices: %w[male female])
  end

  test "an unknown value falls back to the raw value" do
    assert_equal "other", label_for("other", choices: [["Male", "male"]])
  end

  test "a nil value resolves to nil (renders the placeholder)" do
    assert_nil label_for(nil, choices: [["Male", "male"]])
  end

  test "multiple values join their labels" do
    choices = [["Admin", "admin"], ["Member", "member"]]
    assert_equal "Admin, Member", label_for(%w[admin member], choices: choices)
  end
end

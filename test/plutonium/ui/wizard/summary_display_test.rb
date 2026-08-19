# frozen_string_literal: true

require "test_helper"

# Unit tests for the review summary's choice-label resolution. A choice input
# (select/radio_buttons) stores the raw value in `data`; the value -> label map
# lives only in its `choices:`. The summary resolves it with the same mapper the
# form uses so it reads "Female", not "female".
#
# Resolution happens per field, off the `inputs` the summary is handed — there is
# no decorator over the data object, so these drive the real path end to end.
class Plutonium::UI::Wizard::SummaryDisplayTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Wizard::SummaryDisplay

  # Build a component far enough to call resolve_choice_label: it only reads
  # `object` and the passed input_options.
  # `**options` rather than a positional hash plus a `wizard:` kwarg: with both,
  # Ruby binds a caller's bare `choices:` to the keywords instead of the hash.
  def label_for(value, **options)
    component = Component.allocate
    component.instance_variable_set(:@object, Struct.new(:sex).new(value))
    component.instance_variable_set(:@wizard, options.delete(:wizard))
    component.send(:resolve_choice_label, :sex, options)
  end

  # --- shapes ---------------------------------------------------------------

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

  test "a range resolves to the matching member" do
    assert_equal "3", label_for(3, choices: 1..5)
  end

  test "a proc is called and its result resolved" do
    assert_equal "Female", label_for("female", choices: -> { [["Male", "male"], ["Female", "female"]] })
  end

  test "an ActiveRecord relation resolves through id => to_label" do
    org = Organization.create!(name: "Acme")
    assert_equal "Acme", label_for(org.id, choices: Organization.where(id: org.id))
  end

  test "label_method / value_method are honoured alongside choices" do
    pair = Struct.new(:code, :title)
    choices = [pair.new("ng", "Nigeria"), pair.new("gh", "Ghana")]
    assert_equal "Ghana",
      label_for("gh", choices: choices, label_method: :title, value_method: :code)
  end

  # --- fallbacks ------------------------------------------------------------

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

  # A proc'd collection is materialised ONCE per field. Building the mapper per
  # value would re-run the author's query for every element of a multi-select.
  test "the choices collection is materialised once, not once per value" do
    calls = 0
    choices = lambda do
      calls += 1
      [["Admin", "admin"], ["Member", "member"]]
    end

    assert_equal "Admin, Member", label_for(%w[admin member], choices: choices)
    assert_equal 1, calls, "the choices proc must run once per field, not once per selected value"
  end

  # --- proc arity, matching the form -----------------------------------------

  # The form resolves every proc'd input option by arity
  # (Form::Resource#call_option_proc), and Form::Wizard documents
  # `choices: ->(form) { form.wizard… }` as a supported declaration. The summary
  # must apply the same rule — handing the raw proc to the mapper bare-`call`s it,
  # which raises ArgumentError on a declaration the step form renders happily.
  test "an arity-1 choices proc is handed the summary, which stands in for the form" do
    wizard = Struct.new(:tiers).new([["Gold", "gold"], ["Silver", "silver"]])
    choices = ->(form) { form.wizard.tiers }

    assert_equal "Gold", label_for("gold", choices: choices, wizard: wizard)
  end

  test "an arity-1 choices proc can read the staged data off the summary" do
    choices = ->(form) { [[form.object.sex.upcase, "gold"]] }

    assert_equal "GOLD", label_for("gold", choices: choices)
  end

  # A genuinely broken `choices:` is an application error and must surface as one,
  # not degrade to a raw value with a log line nobody reads.
  test "a raising choices proc propagates" do
    assert_raises(RuntimeError) { label_for("gold", choices: -> { raise "boom" }) }
  end
end

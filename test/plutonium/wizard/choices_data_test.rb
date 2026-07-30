# frozen_string_literal: true

require "test_helper"

# {Plutonium::Wizard::ChoicesData} decorates a step's typed data so a field
# declared with `choices:` reads as the LABEL the form's `<option>` carried,
# rather than the raw stored value. It delegates materialisation to the same
# `Phlexi::Form::SimpleChoicesMapper` the select input uses, so the review page
# and the form can't disagree — these tests pin that contract across every
# collection shape the input accepts, plus the fallbacks.
class Plutonium::Wizard::ChoicesDataTest < ActiveSupport::TestCase
  # A stand-in for the wizard's typed data object: plain readers per field.
  def data_for(**attrs)
    Struct.new(*attrs.keys).new(**attrs)
  end

  # A stand-in for a Step: only `inputs` is consulted.
  def step_for(inputs)
    Struct.new(:inputs).new(inputs)
  end

  def wrap(value, options, field: :choice)
    Plutonium::Wizard::ChoicesData.wrap(
      data_for(field => value),
      step_for(field => {options: options})
    )
  end

  # --- shapes ---------------------------------------------------------------

  test "a {value => label} hash resolves to the label" do
    decorated = wrap("cash", {choices: {cash: "Cash", cheque: "Cheque"}})
    assert_equal "Cash", decorated.choice
  end

  test "an [label, value] pair array resolves to the label" do
    decorated = wrap(2, {choices: [["Alice", 1], ["Bob", 2]]})
    assert_equal "Bob", decorated.choice
  end

  test "a flat array of scalars resolves to itself" do
    decorated = wrap("draft", {choices: %w[draft published]})
    assert_equal "draft", decorated.choice
  end

  test "a proc is called and its result resolved" do
    decorated = wrap(3, {choices: -> { [["Small", 1], ["Large", 3]] }})
    assert_equal "Large", decorated.choice
  end

  test "a range resolves to the matching member" do
    decorated = wrap(3, {choices: (1..5)})
    assert_equal "3", decorated.choice
  end

  # The record shapes are what make delegating to Phlexi worth it — reproducing
  # its id/to_label/name/title probing by hand is where a bespoke resolver drifts.
  test "an ActiveRecord relation resolves through id => name" do
    org = Organization.create!(name: "Acme #{SecureRandom.hex(4)}")
    decorated = wrap(org.id, {choices: Organization.where(id: org.id)})
    assert_equal org.name, decorated.choice
  end

  test "label_method / value_method are honoured alongside choices" do
    org = Organization.create!(name: "Beta #{SecureRandom.hex(4)}")
    decorated = wrap(org.name, {choices: [org], label_method: :id, value_method: :name})
    assert_equal org.id.to_s, decorated.choice
  end

  # --- multi-select ---------------------------------------------------------

  test "a multi-select array labels every element" do
    decorated = wrap([1, 2], {choices: [["Alice", 1], ["Bob", 2]]})
    assert_equal ["Alice", "Bob"], decorated.choice
  end

  # --- fallbacks ------------------------------------------------------------

  test "a value absent from the choices falls back to the raw value" do
    decorated = wrap("wire", {choices: {cash: "Cash"}})
    assert_equal "wire", decorated.choice
  end

  test "nil and blank pass through untouched" do
    assert_nil wrap(nil, {choices: {cash: "Cash"}}).choice
    assert_equal "", wrap("", {choices: {cash: "Cash"}}).choice
  end

  test "a raising choices proc degrades to the raw value instead of blowing up the page" do
    decorated = wrap("42", {choices: -> { raise "boom" }})
    assert_equal "42", decorated.choice
  end

  # --- decoration boundaries ------------------------------------------------

  test "wrap is a no-op when no field declares choices" do
    data = data_for(note: "hi")
    assert_same data, Plutonium::Wizard::ChoicesData.wrap(data, step_for(note: {options: {as: :textarea}}))
  end

  test "fields without choices delegate unchanged" do
    decorated = Plutonium::Wizard::ChoicesData.wrap(
      data_for(choice: "cash", note: "keep me"),
      step_for(choice: {options: {choices: {cash: "Cash"}}}, note: {options: {as: :textarea}})
    )
    assert_equal "Cash", decorated.choice
    assert_equal "keep me", decorated.note
  end

  # Phlexi infers field affordances (required marker, maxlength) from the object's
  # class, so the decorator must not shadow it with SimpleDelegator's own.
  test "it masquerades as the wrapped object's class" do
    data = data_for(choice: "cash")
    decorated = Plutonium::Wizard::ChoicesData.wrap(data, step_for(choice: {options: {choices: {cash: "Cash"}}}))
    assert_equal data.class, decorated.class
  end
end

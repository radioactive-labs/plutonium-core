# frozen_string_literal: true

require "test_helper"

# Regression coverage for Form::Base#initialize_attributes — a blind
# `attributes[:id] ||= "resource-form"` would clobber a caller-provided id
# (which Phlexi has already moved off `attributes` onto `@dom_id`), producing
# duplicate `<form id="resource-form">` elements when a filter slideover and
# a modal resource form coexist on the page.
class Plutonium::UI::Form::BaseIdPreservationTest < ActiveSupport::TestCase
  setup do
    @record = User.new(email: "test@example.com")
    @definition = Plutonium::Definition::Base.new
  end

  test "caller-provided attributes[:id] survives to @dom_id, no resource-form fallback applied" do
    form = build_form(attributes: {id: "filter-form"})

    assert_equal "filter-form", form.instance_variable_get(:@dom_id)
    assert_nil form.send(:attributes)[:id]
  end

  test "no id: falls back to resource-form" do
    form = build_form

    assert_nil form.instance_variable_get(:@dom_id)
    assert_equal "resource-form", form.send(:attributes)[:id]
  end

  private

  def build_form(**extra)
    Plutonium::UI::Form::Resource.new(
      @record,
      resource_fields: [:email],
      resource_definition: @definition,
      singular_resource: false,
      **extra
    )
  end
end

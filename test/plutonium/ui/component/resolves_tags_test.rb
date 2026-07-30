# frozen_string_literal: true

require "test_helper"

# `as:` is a union — an input alias (Symbol/String) or a component Class rendered
# directly. Every surface that renders a field resolves it through
# Builder#component_for, so a Class `as:` behaves identically in forms, displays,
# tables and filter forms instead of raising `NoMethodError: MyComponent_tag` in
# whichever surface hand-rolled only the alias half.
class Plutonium::UI::Component::ResolvesTagsTest < ActiveSupport::TestCase
  # A directly-rendered component takes the field builder, exactly as the
  # built-in tags' components do.
  class FormPickerComponent < Phlexi::Form::Components::Base
    def view_template
      div { "picker" }
    end
  end

  class DisplayCardComponent < Phlexi::Display::Components::Base
    def view_template
      div { "card" }
    end
  end

  # The shape the docs point users at for `as:`: a field component whose input
  # attributes (name, id, value) come from the builder.
  class ColorPickerComponent < Phlexi::Form::Components::Base
    include Phlexi::Form::Components::Concerns::HandlesInput

    def view_template
      input(**attributes, type: "color", value: field.value)
    end
  end

  # A component with its own constructor CANNOT be an `as:` — `as:` hands the
  # component the field builder. Those go through the block form instead.
  class KeywordOnlyComponent < Plutonium::UI::Component::Base
    def initialize(value:)
      @value = value
    end

    def view_template
      div { @value.to_s }
    end
  end

  # A fresh field per call: create_component registers the component on the
  # builder, so one builder can only resolve one tag.
  def form_field(name = :email)
    Plutonium::UI::Form::Resource.new(
      User.new(email: "test@example.com"),
      resource_fields: [name],
      resource_definition: Plutonium::Definition::Base.new,
      singular_resource: false
    ).field(name)
  end

  def display_field(name = :email)
    Plutonium::UI::Display::Base.new(User.new(email: "test@example.com")).field(name)
  end

  # --- form builder ---------------------------------------------------------

  test "a component class renders as that component" do
    assert_instance_of FormPickerComponent, form_field.component_for(FormPickerComponent)
  end

  test "an alias renders through its tag method" do
    assert_instance_of Phlexi::Form::Components::Input, form_field.component_for(:string)
  end

  test "a string alias renders through its tag method" do
    assert_instance_of Phlexi::Form::Components::Input, form_field.component_for("string")
  end

  test "nil infers the tag from the field" do
    assert_instance_of Phlexi::Form::Components::Input, form_field.component_for(nil)
  end

  test "attributes reach an alias tag" do
    component = form_field.component_for(:string, placeholder: "you@example.com")

    assert_equal "you@example.com", component.attributes[:placeholder]
  end

  # A component class is a tag like any other: the surface's attributes reach it
  # through `attributes`, so the filter panel's `class: "w-full"` and a form's
  # `pre_submit` action apply to an `as: MyComponent` too.
  test "attributes reach a component class" do
    component = form_field.component_for(FormPickerComponent, placeholder: "you@example.com")

    assert_equal "you@example.com", component.attributes[:placeholder]
  end

  test "a component class still gets its themed class alongside forwarded attributes" do
    component = form_field.component_for(ColorPickerComponent, "data-action" => "change->form#preSubmit")

    html = component.call

    assert_includes html, 'data-action="change->form#preSubmit"'
    assert_includes html, 'class="color_picker_component optional "'
  end

  # The theme key a directly-rendered component resolves against — the name a
  # user would guess. A bare `sub(/component$/, "")` left the separator behind
  # (`:color_picker_`), so a theme entry for `:color_picker` never matched.
  test "a component class themes off its demodulized name" do
    assert_equal :color_picker, form_field.send(:component_theme_key, ColorPickerComponent)
  end

  test "a class not suffixed Component keeps its whole name as the key" do
    swatch = Class.new(Phlexi::Form::Components::Base)
    def swatch.name = "Admin::Swatch"

    assert_equal :swatch, form_field.send(:component_theme_key, swatch)
  end

  # The documented `as: MyComponent` contract, end to end: the component gets the
  # field, so its input carries the field's name and value.
  test "a field component renders with the field's input attributes" do
    html = form_field.component_for(ColorPickerComponent).call

    assert_includes html, 'name="user[email]"'
    assert_includes html, 'value="test@example.com"'
    assert_includes html, 'type="color"'
  end

  # The boundary the docs describe: a component with its own constructor is not an
  # `as:` candidate — use the block form (see filter_field_test for that path).
  test "a component with its own constructor is rejected by as:" do
    assert_raises(ArgumentError) { form_field.component_for(KeywordOnlyComponent) }
  end

  # --- display builder ------------------------------------------------------

  test "the display builder also resolves a component class" do
    assert_instance_of DisplayCardComponent, display_field.component_for(DisplayCardComponent)
  end

  test "the display builder resolves an alias" do
    assert_instance_of Plutonium::UI::Display::Components::FormattedValue, display_field.component_for(:formatted_value)
  end

  # The table renders cells through its own display builder subclass. It has to
  # resolve a class `as:` too — a column whose field declares `as: SomeComponent`
  # used to raise here while the form and show page rendered it happily.
  test "the table's display builder resolves a component class" do
    field = Plutonium::UI::Table::Base::Display.new(User.new(email: "test@example.com")).field(:email)

    assert_instance_of DisplayCardComponent, field.component_for(DisplayCardComponent)
  end
end

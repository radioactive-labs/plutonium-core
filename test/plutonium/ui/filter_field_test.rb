# frozen_string_literal: true

require "test_helper"

# Filter inputs (the slideover's FilterForm and the inline Query form) render an
# `as:` the same way every other surface does — including a component Class,
# which used to raise `NoMethodError: MyComponent_tag` here.
class Plutonium::UI::FilterFieldTest < ActiveSupport::TestCase
  class PickerComponent < Phlexi::Form::Components::Base
    def view_template
      div { "picker" }
    end
  end

  # A component with its own constructor reaches a field through the block form,
  # which builds it by hand — the documented alternative to `as:`.
  class KeywordOnlyComponent < Plutonium::UI::Component::Base
    def initialize(value:)
      @value = value
    end

    def view_template
      div { @value.to_s }
    end
  end

  FakeDefinition = Struct.new(:defined_inputs, :defined_fields) do
    def initialize(defined_inputs: {}, defined_fields: {})
      super
    end
  end

  FakeQueryObject = Struct.new(:filter_definitions, :scope_definitions) do
    def initialize(filter_definitions: {}, scope_definitions: {})
      super
    end
  end

  def build_filter_form
    Plutonium::UI::Table::Components::FilterForm.new(
      {},
      query_object: FakeQueryObject.new,
      search_url: "/users"
    )
  end

  def build_query_form
    Plutonium::UI::Form::Query.new({}, query_object: FakeQueryObject.new, page_size: 10)
  end

  # render_filter_field needs a live render context for its wrapper markup and a
  # `nested` namespace for the field. Stub the markup, hand it a real field
  # builder, and capture whatever component it renders.
  def render_filter_field(form, definition, name)
    rendered = nil
    form.define_singleton_method(:div) { |*, **, &block| block&.call }
    form.define_singleton_method(:label) { |*, **, &block| block&.call }
    form.define_singleton_method(:render) { |component| rendered = component }
    form.define_singleton_method(:current_param_value) { |*| nil }

    nested = Object.new
    field = form.field(name)
    nested.define_singleton_method(:key) { :q }
    nested.define_singleton_method(:field) { |_name, **, &block| block.call(field) }

    form.send(:render_filter_field, nested, definition, name)
    rendered
  end

  test "the filter slideover renders a component-class as:" do
    definition = FakeDefinition.new(defined_inputs: {email: {options: {as: PickerComponent}}})

    assert_instance_of PickerComponent, render_filter_field(build_filter_form, definition, :email)
  end

  test "the filter slideover still renders an alias as:" do
    definition = FakeDefinition.new(defined_inputs: {email: {options: {as: :string}}})

    assert_instance_of Phlexi::Form::Components::Input, render_filter_field(build_filter_form, definition, :email)
  end

  test "a block-form input renders a component built with its own constructor" do
    definition = FakeDefinition.new(defined_inputs: {email: {block: ->(f) { KeywordOnlyComponent.new(value: f.value) }}})

    assert_instance_of KeywordOnlyComponent, render_filter_field(build_filter_form, definition, :email)
  end

  test "the inline query form renders a component-class as:" do
    definition = FakeDefinition.new(defined_inputs: {email: {options: {as: PickerComponent}}})

    assert_instance_of PickerComponent, render_filter_field(build_query_form, definition, :email)
  end

  test "the inline query form still renders an alias as:" do
    definition = FakeDefinition.new(defined_inputs: {email: {options: {as: :string}}})

    assert_instance_of Phlexi::Form::Components::Input, render_filter_field(build_query_form, definition, :email)
  end
end

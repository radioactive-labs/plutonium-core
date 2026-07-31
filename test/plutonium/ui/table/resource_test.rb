# frozen_string_literal: true

require "test_helper"

# Regression: a table column whose `as:` is a component Class (declared on the
# field, display or column) used to hit `f.send(:"#{tag}_tag")` and raise
# `NoMethodError: CardComponent_tag` — while the same declaration rendered fine
# in the form and on the show page, which both branched on `tag.is_a?(Class)`.
# Columns now resolve the tag through Builder#component_for like everything else.
class Plutonium::UI::Table::ResourceTest < ActiveSupport::TestCase
  class CardComponent < Phlexi::Display::Components::Base
    def view_template
      div { "card" }
    end
  end

  FakeDefinition = Struct.new(:defined_fields, :defined_displays, :defined_columns, :defined_actions) do
    def initialize(defined_fields: {}, defined_displays: {}, defined_columns: {}, defined_actions: {})
      super
    end
  end

  # Drive render_table without a live render context: stub `render` to hand the
  # table-building block a recorder, then invoke the captured column block with a
  # field builder from the table's real display builder.
  def column_blocks_for(definition, fields: [:email])
    component = Plutonium::UI::Table::Resource.new(
      [User.new(email: "test@example.com")],
      resource_fields: fields,
      resource_definition: definition
    )

    blocks = {}
    recorder = Object.new
    recorder.define_singleton_method(:selection_column) { |*, **| }
    recorder.define_singleton_method(:actions) { |&_block| }
    recorder.define_singleton_method(:column) { |name, **, &block| blocks[name] = block }

    query_object = Object.new
    query_object.define_singleton_method(:sort_params_for) { |_name| nil }

    component.define_singleton_method(:current_query_object) { query_object }
    component.define_singleton_method(:render) { |_table, &block| block.call(recorder) }

    component.send(:render_table)
    blocks
  end

  def render_cell(block, name = :email)
    display = Plutonium::UI::Table::Base::Display.new(User.new(email: "test@example.com"))
    wrapped_object = Object.new
    wrapped_object.define_singleton_method(:field) { |key| display.field(key) }

    block.call(wrapped_object, name)
  end

  test "a column renders a component-class as: declared on the field" do
    definition = FakeDefinition.new(defined_fields: {email: {options: {as: CardComponent}}})

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of CardComponent, cell
  end

  test "a column renders a component-class as: declared on the column" do
    definition = FakeDefinition.new(defined_columns: {email: {options: {as: CardComponent}}})

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of CardComponent, cell
  end

  test "a column still renders an alias as: through its tag method" do
    definition = FakeDefinition.new(defined_columns: {email: {options: {as: :formatted_value}}})

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of Plutonium::UI::Display::Components::FormattedValue, cell
  end

  test "a column with no as: infers its tag" do
    cell = render_cell(column_blocks_for(FakeDefinition.new)[:email])

    assert_kind_of Phlexi::Display::Components::Base, cell
  end
end

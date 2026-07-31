# frozen_string_literal: true

require "test_helper"

# Regression: a table column whose `as:` is a component Class (declared on the
# field, display or column) used to hit `f.send(:"#{tag}_tag")` and raise
# `NoMethodError: CardComponent_tag` — while the same declaration rendered fine
# in the form and on the show page, which both branched on `tag.is_a?(Class)`.
# Columns now resolve the tag through Builder#component_for like everything else.
#
# Also covers the drag-reorder grip: which column carries it, when it is live,
# and when it degrades to the "sort by position to reorder" link.
class Plutonium::UI::Table::ResourceTest < ActiveSupport::TestCase
  class CardComponent < Phlexi::Display::Components::Base
    def view_template
      div { "card" }
    end
  end

  FakeDefinition = Struct.new(:defined_fields, :defined_displays, :defined_columns, :defined_actions, :defined_position_config) do
    def initialize(defined_fields: {}, defined_displays: {}, defined_columns: {}, defined_actions: {}, defined_position_config: nil)
      super
    end
  end

  # Stands in for QueryObject. `sorted_by` is the field the collection is
  # ordered by, `direction` its direction — nil means "sorted by something we
  # don't care about", which is the foreign-sort case.
  def fake_query_object(sorted_by: nil, direction: "ASC")
    query = Object.new
    query.define_singleton_method(:sort_params_for) do |name|
      {url: "/users?q%5Bsort_fields%5D%5B%5D=#{name}"}
    end
    query.define_singleton_method(:sorted_ascending_only_by?) do |name|
      sorted_by.to_s == name.to_s && direction == "ASC"
    end
    query
  end

  # Drive render_table without a live render context: stub `render` to hand the
  # table-building block a recorder, then invoke the captured column block with a
  # field builder from the table's real display builder.
  #
  # Returns [column blocks by name, the Table::Base that was built].
  def build_table(definition, fields: [:email], query_object: nil, repositionable: true)
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

    query_object ||= fake_query_object
    component.define_singleton_method(:current_query_object) { query_object }
    component.define_singleton_method(:current_page_path) { "/users" }

    policy = Object.new
    policy.define_singleton_method(:allowed_to?) { |_rule| repositionable }
    component.define_singleton_method(:policy_for) { |**| policy }

    table = nil
    component.define_singleton_method(:render) { |built, &block|
      table = built
      block.call(recorder)
    }

    component.send(:render_table)
    [blocks, table]
  end

  def column_blocks_for(definition, **)
    build_table(definition, **).first
  end

  def render_cell(block, name = :email)
    display = Plutonium::UI::Table::Base::Display.new(User.new(email: "test@example.com"))
    wrapped_object = Object.new
    wrapped_object.define_singleton_method(:field) { |key| display.field(key) }
    wrapped_object.define_singleton_method(:unwrapped) { User.new(email: "test@example.com") }

    block.call(wrapped_object, name)
  end

  def positioned_definition(**)
    FakeDefinition.new(
      defined_position_config: Plutonium::Positioning::Config.attribute(:position),
      **
    )
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

  # ─── drag grip ───────────────────────────────────────────────────────────────

  test "a resource with no position_on renders no grip and wires no controller" do
    blocks, table = build_table(FakeDefinition.new)

    assert_not_kind_of Plutonium::UI::Table::Components::DragHandle::Cell, render_cell(blocks[:email])
    assert_nil table.options[:positioned_url_template]
  end

  test "position_on in ascending position order renders a live grip on the first column" do
    blocks, table = build_table(
      positioned_definition,
      fields: [:email, :first_name],
      query_object: fake_query_object(sorted_by: :position)
    )

    cell = render_cell(blocks[:email])
    assert_instance_of Plutonium::UI::Table::Components::DragHandle::Cell, cell
    # Live: no fallback sort link.
    assert_nil cell.instance_variable_get(:@sort_url)

    # ONE grip per row — the second column is untouched.
    assert_not_kind_of Plutonium::UI::Table::Components::DragHandle::Cell,
      render_cell(blocks[:first_name], :first_name)

    assert_equal "/users/__ID__/reposition", table.options[:positioned_url_template]
  end

  test "a foreign sort renders the grip disabled and wires no controller" do
    blocks, table = build_table(
      positioned_definition,
      query_object: fake_query_object(sorted_by: :email)
    )

    cell = render_cell(blocks[:email])
    assert_instance_of Plutonium::UI::Table::Components::DragHandle::Cell, cell
    assert_equal "/users?q%5Bsort_fields%5D%5B%5D=position", cell.instance_variable_get(:@sort_url)

    # The server would reject the drop, so the client must not offer it.
    assert_nil table.options[:positioned_url_template]
  end

  test "a DESCENDING position sort renders the grip disabled" do
    blocks, table = build_table(
      positioned_definition,
      query_object: fake_query_object(sorted_by: :position, direction: "DESC")
    )

    assert_not_nil render_cell(blocks[:email]).instance_variable_get(:@sort_url)
    assert_nil table.options[:positioned_url_template]
  end

  test "position_on false renders no grip" do
    definition = FakeDefinition.new(defined_position_config: Plutonium::Positioning::Config.disabled)

    blocks, table = build_table(definition, query_object: fake_query_object(sorted_by: :position))

    assert_not_kind_of Plutonium::UI::Table::Components::DragHandle::Cell, render_cell(blocks[:email])
    assert_nil table.options[:positioned_url_template]
  end

  test "a record the policy forbids reordering gets no grip" do
    blocks, = build_table(
      positioned_definition,
      query_object: fake_query_object(sorted_by: :position),
      repositionable: false
    )

    assert_not_kind_of Plutonium::UI::Table::Components::DragHandle::Cell, render_cell(blocks[:email])
  end

  test "the grip skips a conditionally hidden first column" do
    definition = positioned_definition(defined_columns: {email: {options: {condition: -> { false }}}})

    blocks, = build_table(definition, fields: [:email, :first_name], query_object: fake_query_object(sorted_by: :position))

    assert_nil blocks[:email]
    assert_instance_of Plutonium::UI::Table::Components::DragHandle::Cell,
      render_cell(blocks[:first_name], :first_name)
  end

  # ─── the grip itself ─────────────────────────────────────────────────────────

  test "a live grip is a draggable button" do
    html = Plutonium::UI::Table::Components::DragHandle.new.call

    assert_includes html, "data-positioned-grip"
    assert_includes html, 'draggable="true"'
    assert_includes html, "<button"
    # NEVER on the <tr>: that would kill text selection and fight row-click.
    assert_includes html, "Drag to reorder"
  end

  test "a disabled grip is a link back to position order" do
    html = Plutonium::UI::Table::Components::DragHandle.new(sort_url: "/users?sort=position").call

    assert_includes html, "<a"
    assert_includes html, 'href="/users?sort=position"'
    assert_includes html, "Sort by position to reorder"
    # Nothing draggable — the server would reject the drop.
    assert_not_includes html, "draggable"
    assert_not_includes html, "data-positioned-grip"
  end

  # ─── the table element wiring ────────────────────────────────────────────────

  test "the table wrapper carries the controller and every row its record id" do
    table = Plutonium::UI::Table::Base.new(
      [User.new(email: "a@example.com")],
      positioned_url_template: "/users/__ID__/reposition"
    )
    wrapped = Phlexi::Table::WrappedObject.new(
      User.new(id: 7, email: "a@example.com"), index: 0, display_class: Plutonium::UI::Table::Base::Display
    )

    wrapper = table.send(:table_wrapper_attributes)
    assert_equal "positioned", wrapper[:data][:controller]
    assert_equal "/users/__ID__/reposition", wrapper[:data][:positioned_url_template_value]

    row = table.send(:table_body_row_attributes, wrapped)
    assert_equal 7, row[:data][:positioned_row_id]
    # row-click must survive alongside it.
    assert_equal "row-click", row[:data][:controller]
    assert_includes row[:class], "group/row"
  end

  test "an unpositioned table wrapper carries no controller and no row ids" do
    table = Plutonium::UI::Table::Base.new([User.new(email: "a@example.com")])
    wrapped = Phlexi::Table::WrappedObject.new(
      User.new(id: 7, email: "a@example.com"), index: 0, display_class: Plutonium::UI::Table::Base::Display
    )

    assert_nil table.send(:table_wrapper_attributes)[:data]
    assert_nil table.send(:table_body_row_attributes, wrapped)[:data][:positioned_row_id]
  end
end

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
  # Returns [column blocks by name, the Table::Base that was built, the
  # Table::Resource component, column options by name].
  def build_table(definition, fields: [:email], query_object: nil, repositionable: true)
    component = Plutonium::UI::Table::Resource.new(
      [User.new(email: "test@example.com")],
      resource_fields: fields,
      resource_definition: definition
    )

    blocks = {}
    options = {}
    recorder = Object.new
    recorder.define_singleton_method(:selection_column) { |*, **| }
    recorder.define_singleton_method(:actions) { |&_block| }
    recorder.define_singleton_method(:column) { |name, **opts, &block|
      blocks[name] = block
      options[name] = opts
    }

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
    [blocks, table, component, options]
  end

  def column_blocks_for(definition, **)
    build_table(definition, **).first
  end

  def column_options_for(definition, **)
    build_table(definition, **).last
  end

  # A column block's cell is a zero-arity proc that renders against the
  # Table::Resource (its lexical self), so rendering it needs that component to
  # be mid-render: swap the stubbed `render` back out and run a real render pass
  # with the cell as the whole template.
  def render_cell_html(definition, name = :email, **)
    blocks, _table, component = build_table(definition, **)
    cell = render_cell(blocks[name], name)

    component.singleton_class.remove_method(:render)
    component.define_singleton_method(:view_template) { render cell }
    component.call
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

  # Regression: `display :x, as: :badge` (or a component class) must reach the
  # table column when no `column` is declared. The table read the type from the
  # wrong key (`display_definition[:as]`, always nil) instead of
  # `display_definition[:options][:as]`, so display-only `as:` silently fell back
  # to the inferred component — while the show page rendered it correctly.
  test "a column inherits an alias as: declared on the display" do
    definition = FakeDefinition.new(defined_displays: {email: {options: {as: :formatted_value}}})

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of Plutonium::UI::Display::Components::FormattedValue, cell
  end

  test "a column inherits a component-class as: declared on the display" do
    definition = FakeDefinition.new(defined_displays: {email: {options: {as: CardComponent}}})

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of CardComponent, cell
  end

  test "a column with no as: infers its tag" do
    cell = render_cell(column_blocks_for(FakeDefinition.new)[:email])

    assert_kind_of Phlexi::Display::Components::Base, cell
  end

  # Uses an unconsumed key (`data_probe`): a component's build_attributes deletes
  # the options it knows (badge eats :colors), so a stray key is what survives to
  # prove where attributes flow.
  test "a column inheriting the display's type also inherits its attributes" do
    definition = FakeDefinition.new(defined_displays: {email: {options: {as: :badge, data_probe: "x"}}})

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of Plutonium::UI::Display::Components::Badge, cell
    assert_equal "x", cell.attributes[:data_probe]
  end

  # A column that says anything about RENDERING (as:, a component attribute, or
  # a block) renders alone: its own type and attributes, no display inheritance,
  # even when the types match.
  test "a column with its own as: does not inherit the display's attributes" do
    definition = FakeDefinition.new(
      defined_displays: {email: {options: {as: :badge, data_probe: "x"}}},
      defined_columns: {email: {options: {as: :badge}}}
    )

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of Plutonium::UI::Display::Components::Badge, cell
    refute cell.attributes.key?(:data_probe), "a column that renders alone must not inherit the display's attributes"
  end

  test "a column with its own attributes does not inherit the display's type" do
    definition = FakeDefinition.new(
      defined_displays: {email: {options: {as: :badge}}},
      defined_columns: {email: {options: {class: "x"}}}
    )

    cell = render_cell(column_blocks_for(definition)[:email])

    refute_instance_of Plutonium::UI::Display::Components::Badge, cell
  end

  # A column that only touches the HEADER (align:, label:, condition:) layers
  # on top of whatever the display renders, so `column :price, align: :end`
  # keeps the display's badge.
  test "a column that only sets align keeps the display's type and attributes" do
    definition = FakeDefinition.new(
      defined_displays: {email: {options: {as: :badge, data_probe: "x"}}},
      defined_columns: {email: {options: {align: :end}}}
    )

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of Plutonium::UI::Display::Components::Badge, cell
    assert_equal "x", cell.attributes[:data_probe]
  end

  test "a column that only sets label keeps the display's type" do
    definition = FakeDefinition.new(
      defined_displays: {email: {options: {as: :badge}}},
      defined_columns: {email: {options: {label: "Login"}}}
    )

    cell = render_cell(column_blocks_for(definition)[:email])

    assert_instance_of Plutonium::UI::Display::Components::Badge, cell
  end

  # ─── header options: label, align, condition ─────────────────────────────────

  test "a display's label reaches the column header" do
    definition = FakeDefinition.new(defined_displays: {email: {options: {label: "Login"}}})

    assert_equal "Login", column_options_for(definition)[:email][:label]
  end

  test "a column's label wins over the display's label" do
    definition = FakeDefinition.new(
      defined_displays: {email: {options: {label: "Login"}}},
      defined_columns: {email: {options: {label: "Sign-in"}}}
    )

    assert_equal "Sign-in", column_options_for(definition)[:email][:label]
  end

  test "align declared on the field reaches the column header" do
    definition = FakeDefinition.new(defined_fields: {email: {options: {align: :end}}})

    assert_equal :end, column_options_for(definition)[:email][:align]
  end

  test "a column's align wins over the field's align" do
    definition = FakeDefinition.new(
      defined_fields: {email: {options: {align: :end}}},
      defined_columns: {email: {options: {align: :center}}}
    )

    assert_equal :center, column_options_for(definition)[:email][:align]
  end

  test "align never reaches the cell component as an attribute" do
    definition = FakeDefinition.new(
      defined_displays: {email: {options: {as: :badge}}},
      defined_columns: {email: {options: {align: :end}}}
    )

    cell = render_cell(column_blocks_for(definition)[:email])

    refute cell.attributes.key?(:align)
  end

  # A `field` condition is surface-neutral (the form and show page both honour
  # it), so the table must too. A `display` condition stays show-only: it may
  # reference `object`, and the table has no single record.
  test "a field condition hides the column" do
    definition = FakeDefinition.new(defined_fields: {email: {options: {condition: -> { false }}}})

    assert_nil column_blocks_for(definition)[:email]
  end

  test "a display condition does not hide the column" do
    definition = FakeDefinition.new(defined_displays: {email: {options: {condition: -> { false }}}})

    assert_not_nil column_blocks_for(definition)[:email]
  end

  test "a form-only field-level key on a display is stripped, not leaked as an attribute" do
    definition = FakeDefinition.new(defined_displays: {email: {options: {hint: "help"}}})

    cell = render_cell(column_blocks_for(definition)[:email])

    refute cell.attributes.key?(:hint), ":hint is a form key; on a display it must be stripped, not rendered as an attribute"
  end

  # ─── column blocks render in the table page's Phlex context ─────────────────
  #
  # Parity with `display` blocks, which are instance_exec'd by Display::Resource:
  # a column block is instance_exec'd by Table::Resource, so `self` has
  # `resource_definition`, `current_user`, `helpers` and the tag methods.

  test "a column block can emit markup directly" do
    definition = FakeDefinition.new(defined_columns: {email: {block: ->(record) { span(class: "x") { record.email } }}})

    assert_equal '<span class="x">test@example.com</span>', render_cell_html(definition)
  end

  test "a column block that returns a String renders it as escaped text" do
    definition = FakeDefinition.new(defined_columns: {email: {block: ->(record) { "<b>#{record.email}</b>" }}})

    assert_equal "&lt;b&gt;test@example.com&lt;/b&gt;", render_cell_html(definition)
  end

  class PlainChip < Plutonium::UI::Component::Base
    def initialize(text) = (@text = text)
    def view_template = strong { @text }
  end

  test "a column block that returns a component renders the component" do
    definition = FakeDefinition.new(defined_columns: {email: {block: ->(record) { PlainChip.new(record.email) }}})

    assert_equal "<strong>test@example.com</strong>", render_cell_html(definition)
  end

  test "a column block that returns a number renders it as text" do
    definition = FakeDefinition.new(defined_columns: {email: {block: ->(record) { record.email.size }}})

    assert_equal "16", render_cell_html(definition)
  end

  test "a column block runs with the table page as self" do
    definition = FakeDefinition.new(
      defined_fields: {email: {options: {label: "Login"}}},
      defined_columns: {email: {block: ->(_record) { resource_definition.defined_fields[:email][:options][:label] }}}
    )

    assert_equal "Login", render_cell_html(definition)
  end

  test "a column block renders inside the drag-handle cell" do
    definition = positioned_definition(defined_columns: {email: {block: ->(record) { span { record.email } }}})

    html = render_cell_html(definition, query_object: fake_query_object(sorted_by: :position))

    assert_includes html, "<span>test@example.com</span>"
    assert_includes html, "data-positioned-grip"
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

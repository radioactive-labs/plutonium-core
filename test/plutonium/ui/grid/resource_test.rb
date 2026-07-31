# frozen_string_literal: true

require "test_helper"

# The grid view's half of drag-to-reorder: which cards get a grip, when the grip
# is live, and when the grid wrapper wires the Stimulus controller.
#
# Mirrors the table's coverage in test/plutonium/ui/table/resource_test.rb — the
# two surfaces share Component::Positionable, so the point of testing both is
# that each SURFACE consumes it correctly, not that the predicate works twice.
class Plutonium::UI::Grid::ResourceTest < ActiveSupport::TestCase
  # Stands in for QueryObject. `sorted_by` is the field the collection is
  # ordered by, `direction` its direction — nil means "sorted by something we
  # don't care about", which is the foreign-sort case.
  def fake_query_object(sorted_by: nil, direction: "ASC")
    query = Object.new
    query.define_singleton_method(:sort_params_for) do |name|
      {url: "/tasks?q%5Bsort_fields%5D%5B%5D=#{name}"}
    end
    query.define_singleton_method(:sorted_ascending_only_by?) do |name|
      sorted_by.to_s == name.to_s && direction == "ASC"
    end
    query
  end

  def fake_definition(position_config)
    definition = Object.new
    definition.define_singleton_method(:defined_position_config) { position_config }
    definition
  end

  def build_grid(position_config: nil, query_object: nil, repositionable: true)
    component = Plutonium::UI::Grid::Resource.new(
      [User.new(email: "test@example.com")],
      resource_fields: [:email],
      resource_definition: fake_definition(position_config)
    )

    query_object ||= fake_query_object
    component.define_singleton_method(:current_query_object) { query_object }
    component.define_singleton_method(:current_page_path) { "/tasks" }

    policy = Object.new
    policy.define_singleton_method(:allowed_to?) { |_rule| repositionable }
    component.define_singleton_method(:policy_for) { |**| policy }

    component
  end

  def positioned_config = Plutonium::Positioning::Config.attribute(:position)

  # ─── the grid wrapper ────────────────────────────────────────────────────────

  test "a resource with no position_on wires no controller and renders no grip" do
    grid = build_grid

    assert_equal({}, grid.send(:grid_data))
    assert_nil grid.send(:drag_handle_for, User.new)
  end

  test "position_on in ascending position order wires the controller on the horizontal axis" do
    grid = build_grid(
      position_config: positioned_config,
      query_object: fake_query_object(sorted_by: :position)
    )

    data = grid.send(:grid_data)
    assert_equal "positioned", data[:controller]
    assert_equal "/tasks/__ID__/reposition", data[:positioned_url_template_value]
    # Cards wrap, so the vertical midpoint test the table uses would collapse a
    # whole row of cards into one slot.
    assert_equal "horizontal", data[:positioned_axis_value]
  end

  test "a live grip carries no fallback sort link and uses the card variant" do
    grid = build_grid(
      position_config: positioned_config,
      query_object: fake_query_object(sorted_by: :position)
    )

    handle = grid.send(:drag_handle_for, User.new)
    assert_instance_of Plutonium::UI::Table::Components::DragHandle, handle
    assert_nil handle.instance_variable_get(:@sort_url)
    assert_includes handle.call, "group-hover/card"
  end

  test "a foreign sort renders the grip disabled and wires no controller" do
    grid = build_grid(
      position_config: positioned_config,
      query_object: fake_query_object(sorted_by: :email)
    )

    handle = grid.send(:drag_handle_for, User.new)
    assert_equal "/tasks?q%5Bsort_fields%5D%5B%5D=position", handle.instance_variable_get(:@sort_url)

    # The server would reject the drop, so the client must not offer it.
    assert_equal({}, grid.send(:grid_data))
  end

  test "a DESCENDING position sort renders the grip disabled and wires no controller" do
    grid = build_grid(
      position_config: positioned_config,
      query_object: fake_query_object(sorted_by: :position, direction: "DESC")
    )

    assert_not_nil grid.send(:drag_handle_for, User.new).instance_variable_get(:@sort_url)
    assert_equal({}, grid.send(:grid_data))
  end

  test "position_on false renders no grip" do
    grid = build_grid(
      position_config: Plutonium::Positioning::Config.disabled,
      query_object: fake_query_object(sorted_by: :position)
    )

    assert_nil grid.send(:drag_handle_for, User.new)
    assert_equal({}, grid.send(:grid_data))
  end

  test "a record the policy forbids reordering gets no grip" do
    grid = build_grid(
      position_config: positioned_config,
      query_object: fake_query_object(sorted_by: :position),
      repositionable: false
    )

    assert_nil grid.send(:drag_handle_for, User.new)
    # The wrapper is still wired — other cards in the same collection may well
    # be draggable, and the controller reads ids off the cards, not the wrapper.
    assert_equal "positioned", grid.send(:grid_data)[:controller]
  end

  # ─── the card variant of the grip ────────────────────────────────────────────

  test "a live card grip is a draggable button" do
    html = Plutonium::UI::Table::Components::DragHandle.new(variant: :card).call

    assert_includes html, "data-positioned-grip"
    assert_includes html, 'draggable="true"'
    # Floated over the card's corner — a card has no gutter to tuck it into.
    assert_includes html, "absolute"
  end

  test "a disabled card grip is a link back to position order" do
    html = Plutonium::UI::Table::Components::DragHandle.new(sort_url: "/tasks?sort=position", variant: :card).call

    assert_includes html, 'href="/tasks?sort=position"'
    assert_includes html, "group-hover/card"
    assert_not_includes html, "data-positioned-grip"
  end

  test "an unknown variant fails loudly at construction" do
    assert_raises(KeyError) { Plutonium::UI::Table::Components::DragHandle.new(variant: :nope) }
  end
end

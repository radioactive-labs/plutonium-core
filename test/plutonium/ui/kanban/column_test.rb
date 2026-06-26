# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Kanban::ColumnTest < Minitest::Test
  # ---------------------------------------------------------------------------
  # Pure helpers — no Phlex render context needed
  # ---------------------------------------------------------------------------

  def test_more_count_zero_when_total_equals_cards
    col = build_column(:todo)
    component = build_component(col, cards: stub_records(3), total: 3, per_column: 10)
    assert_equal 0, component.send(:more_count)
  end

  def test_more_count_when_total_exceeds_cards
    col = build_column(:todo)
    cards = stub_records(3)
    component = build_component(col, cards: cards, total: 10, per_column: 3)
    assert_equal 7, component.send(:more_count)
  end

  def test_more_count_never_negative
    col = build_column(:todo)
    # total < cards.size shouldn't happen in practice, but guard against it
    component = build_component(col, cards: stub_records(5), total: 3, per_column: 5)
    assert_equal 0, component.send(:more_count)
  end

  def test_wip_over_limit_false_when_no_wip
    col = build_column(:todo)  # no wip
    component = build_component(col, cards: stub_records(10), total: 10)
    refute component.send(:wip_over_limit?)
  end

  def test_wip_over_limit_false_when_within_limit
    col = build_column(:doing, wip: 3)
    component = build_component(col, cards: stub_records(3), total: 3)
    refute component.send(:wip_over_limit?)
  end

  def test_wip_over_limit_true_when_exceeded
    col = build_column(:doing, wip: 3)
    component = build_component(col, cards: stub_records(4), total: 4)
    assert component.send(:wip_over_limit?)
  end

  # ---------------------------------------------------------------------------
  # Expanded column HTML — stub render_cards to avoid view_context
  # ---------------------------------------------------------------------------

  def test_renders_column_key_as_data_attribute
    col = build_column(:todo)
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/data-kanban-column-key="todo"/, html)
  end

  def test_renders_column_label_in_header
    col = build_column(:doing)
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/Doing/, html)
  end

  def test_renders_wip_badge_when_wip_set
    col = build_column(:doing, wip: 3)
    component = build_component(col, cards: stub_records(2), total: 2)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/2\/3/, html, "wip badge should show count/limit")
  end

  def test_wip_badge_has_danger_class_when_over_limit
    col = build_column(:doing, wip: 3)
    component = build_component(col, cards: stub_records(4), total: 4)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/pu-badge-danger/, html, "over-limit wip badge should have danger class")
  end

  def test_wip_badge_does_not_have_danger_class_when_within_limit
    col = build_column(:doing, wip: 3)
    component = build_component(col, cards: stub_records(2), total: 2)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_match(/pu-badge-danger/, html, "within-limit wip badge should not have danger class")
  end

  def test_no_wip_badge_when_wip_not_set
    col = build_column(:todo)  # no wip
    component = build_component(col, cards: stub_records(5), total: 5)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_match(/\/\d+/, html, "wip badge should not appear when wip is not set")
  end

  def test_renders_more_footer_when_total_exceeds_per_column
    col = build_column(:todo)
    cards = stub_records(5)
    component = build_component(col, cards: cards, total: 12, per_column: 5)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/\+7 more/, html, "'+7 more' footer should appear when total > per_column")
  end

  def test_no_more_footer_when_total_equals_per_column
    col = build_column(:todo)
    cards = stub_records(5)
    component = build_component(col, cards: cards, total: 5, per_column: 5)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_match(/more/, html, "no 'more' footer when total == per_column")
  end

  def test_no_more_footer_when_total_below_per_column
    col = build_column(:todo)
    cards = stub_records(3)
    component = build_component(col, cards: cards, total: 3, per_column: 10)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_match(/more/, html, "no 'more' footer when total < per_column")
  end

  # ---------------------------------------------------------------------------
  # Collapsed strip variant
  # ---------------------------------------------------------------------------

  def test_collapsed_renders_collapsed_strip
    col = build_column(:done, collapsed: true)
    component = build_component(col, cards: stub_records(2), total: 2)
    # Both strip and body are always emitted; stub render_cards so the body
    # renders without needing a full record interface on the stub structs.
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/pu-kanban-column-collapsed/, html)
  end

  def test_collapsed_shows_card_count
    col = build_column(:done, collapsed: true)
    component = build_component(col, cards: stub_records(3), total: 3)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/>3</, html, "collapsed strip should show card count")
  end

  def test_collapsed_shows_column_label
    col = build_column(:done, collapsed: true)
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    assert_match(/Done/, html, "collapsed strip should show column label")
  end

  def test_expanded_does_not_render_collapsed_class
    col = build_column(:todo, collapsed: false)
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_match(/pu-kanban-column-collapsed/, html)
  end

  # ---------------------------------------------------------------------------
  # Quick-add button (column_add_url)
  #
  # The actual link_to requires a Rails view_context and is fully exercised by
  # the integration test (kanban_quick_add_test.rb). These unit tests verify
  # the structural contract using a stubbed render_add_button.
  # ---------------------------------------------------------------------------

  def test_add_button_container_renders_when_column_add_url_set
    col = build_column(:todo, add: true)
    component = build_component_with_add_url(col, add_url: "/tasks/new?kanban_column=todo")
    component.define_singleton_method(:render_cards) { }
    # Stub render_add_button to avoid link_to needing a view context in unit tests.
    component.define_singleton_method(:render_add_button) { span(class: "add-stub") { plain "+ Add" } }

    html = component.call

    assert_includes html, "+ Add", "add button should appear when column_add_url is set"
    assert_match(/flex items-center gap-1 shrink-0/, html,
      "action slot container should wrap the add button")
  end

  def test_no_add_button_when_column_add_url_nil
    col = build_column(:todo, add: true)
    # build_component does not pass column_add_url → defaults to nil
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_includes html, "+ Add", "no add button when column_add_url is nil"
    # No action slot either (no actions, no add_url)
    refute_match(/flex items-center gap-1 shrink-0/, html,
      "no action container when neither add_url nor actions are present")
  end

  def test_action_slot_container_renders_with_only_add_url_and_no_actions
    col = build_column(:doing)  # no actions, no add preset
    component = build_component_with_add_url(col, add_url: "/tasks/new?kanban_column=doing")
    component.define_singleton_method(:render_cards) { }
    component.define_singleton_method(:render_add_button) { span(class: "add-stub") { plain "+ Add" } }

    html = component.call

    assert_match(/flex items-center gap-1 shrink-0/, html,
      "action container renders when only add_url is present (no column actions)")
  end

  # ---------------------------------------------------------------------------
  # Column actions slot
  #
  # Real action links are rendered from controller-threaded `column_action_data`
  # (resolved ids + URL + policy gate), which requires a live view_context. That
  # full rendering is covered by the integration test
  # (test/integration/admin_portal/kanban_column_action_test.rb). These unit
  # tests cover the view-context-free contract: without threaded data, no link
  # renders even when the column declares actions.
  # ---------------------------------------------------------------------------

  def test_no_action_link_without_threaded_column_action_data
    col = build_column(:done)
    col.action(:archive_all, interaction: Object, on: :all, label: "Archive all")
    # column_action_data defaults to [] — controller hasn't threaded ids in yet.
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_match(/Archive all/, html,
      "no action link should render until the controller threads column_action_data")
    refute_match(/data-kanban-action/, html)
  end

  def test_action_slot_div_present_when_column_has_actions
    col = build_column(:done)
    col.action(:archive_all, interaction: Object, on: :all, label: "Archive all")
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    # The action slot container renders (header calls render_column_actions),
    # but it is empty until column_action_data is threaded in.
    assert_match(/flex items-center gap-1 shrink-0/, html,
      "action slot container should render when the column declares actions")
  end

  def test_no_action_slot_when_column_has_no_actions
    col = build_column(:todo)  # no actions added
    component = build_component(col, cards: [], total: 0)
    component.define_singleton_method(:render_cards) { }

    html = component.call

    refute_match(/data-kanban-action/, html)
  end

  private

  def build_column(key, **opts)
    Plutonium::Kanban::Column.new(key, **opts)
  end

  def build_component(column, cards:, total:, per_column: 10)
    Plutonium::UI::Kanban::Column.new(
      column: column,
      cards: cards,
      total: total,
      per_column: per_column,
      resource_definition: nil,
      resource_fields: []
    )
  end

  def build_component_with_add_url(column, add_url:, cards: [], total: 0, per_column: 10)
    Plutonium::UI::Kanban::Column.new(
      column: column,
      cards: cards,
      total: total,
      per_column: per_column,
      resource_definition: nil,
      resource_fields: [],
      column_add_url: add_url
    )
  end

  def stub_records(count)
    count.times.map { Struct.new(:id).new(SecureRandom.random_number(1000)) }
  end
end

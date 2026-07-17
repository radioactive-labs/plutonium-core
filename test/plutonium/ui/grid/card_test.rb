# frozen_string_literal: true

require "test_helper"

# Unit tests for Grid::Card#slots override via card_fields parameter.
#
# The `slots` method normally reads from resource_definition.defined_grid_fields.
# When a `card_fields:` hash is passed at construction time it should take
# precedence over the definition's grid_fields, letting the kanban board
# declare its own slot layout without changing the resource definition.
class Plutonium::UI::Grid::CardSlotsTest < Minitest::Test
  def test_slots_uses_card_fields_when_provided
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition,
      card_fields: {header: :title, meta: [:status]}
    )

    assert_equal({header: :title, meta: [:status]}, card.send(:slots))
  end

  def test_slots_falls_back_to_definition_when_card_fields_nil
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition,
      card_fields: nil
    )

    assert_equal({header: :name}, card.send(:slots))
  end

  def test_slots_falls_back_to_definition_when_card_fields_not_given
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition
    )

    assert_equal({header: :name}, card.send(:slots))
  end

  def test_card_fields_empty_hash_overrides_definition
    # An explicitly passed empty hash means "render no slots",
    # distinct from nil which means "use the definition".
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition,
      card_fields: {}
    )

    assert_equal({}, card.send(:slots))
  end

  private

  def stub_definition(grid_fields:)
    d = Object.new
    d.define_singleton_method(:defined_grid_fields) { grid_fields }
    d
  end

  def stub_record
    Struct.new(:id).new(1)
  end
end

# Unit tests for Grid::Card#footer_field.
#
# The footer slot falls back to :created_at when undeclared, so — unlike every
# other slot — omitting it does NOT remove the footer. `footer: false` is the
# opt-out for cards that want no footer line at all.
class Plutonium::UI::Grid::CardFooterFieldTest < Minitest::Test
  def test_footer_falls_back_to_created_at_when_slot_undeclared
    assert_equal :created_at, footer_field_for({header: :title})
  end

  def test_footer_uses_the_declared_slot
    assert_equal :updated_at, footer_field_for({header: :title, footer: :updated_at})
  end

  def test_footer_false_disables_the_footer
    assert_nil footer_field_for({header: :title, footer: false})
  end

  # nil keeps meaning "undeclared" (→ fall back); only false opts out. Guards the
  # back-compat boundary: `footer: some_nil_var` must not silently drop the footer.
  def test_footer_nil_still_falls_back
    assert_equal :created_at, footer_field_for({header: :title, footer: nil})
  end

  def test_footer_is_absent_when_the_record_has_no_created_at
    assert_nil footer_field_for({header: :title}, record: Struct.new(:id).new(1))
  end

  private

  def footer_field_for(card_fields, record: Struct.new(:id, :created_at).new(1, Time.now))
    definition = Object.new
    definition.define_singleton_method(:defined_grid_fields) { {} }
    Plutonium::UI::Grid::Card.new(
      record, resource_definition: definition, card_fields: card_fields
    ).send(:footer_field)
  end
end

# Unit tests for Grid::Card#merge_query_params — the show-link URL builder used
# to tag a kanban-modal card's show URL. Must append cleanly whether or not the
# base URL already carries a query string.
class Plutonium::UI::Grid::CardMergeQueryParamsTest < Minitest::Test
  def test_appends_param_to_a_bare_path
    assert_equal "/tasks/1?kanban_modal=1", merge("/tasks/1", {"kanban_modal" => "1"})
  end

  def test_merges_with_an_existing_query_string
    result = merge("/tasks/1?parent_id=9", {"kanban_modal" => "1"})
    uri = URI.parse(result)
    assert_equal "/tasks/1", uri.path
    assert_equal({"parent_id" => "9", "kanban_modal" => "1"}, Rack::Utils.parse_nested_query(uri.query))
  end

  def test_returns_url_unchanged_when_extra_is_blank
    assert_equal "/tasks/1", merge("/tasks/1", nil)
    assert_equal "/tasks/1", merge("/tasks/1", {})
  end

  private

  def merge(url, extra)
    definition = Object.new
    definition.define_singleton_method(:defined_grid_fields) { {} }
    Plutonium::UI::Grid::Card.new(
      Struct.new(:id).new(1), resource_definition: definition
    ).send(:merge_query_params, url, extra)
  end
end

# Unit tests for Grid::Card#show_link_url_params — a kanban card on a show_in
# :modal board is the only Grid::Card handed the remote-modal frame explicitly,
# so that frame is the signal to tag the show URL for metadata-rail hiding.
class Plutonium::UI::Grid::CardShowLinkUrlParamsTest < Minitest::Test
  def test_tags_the_url_when_show_frame_is_the_remote_modal_frame
    assert_equal(
      {Plutonium::KANBAN_MODAL_PARAM => "1"},
      show_link_url_params_for(Plutonium::REMOTE_MODAL_FRAME)
    )
  end

  def test_no_params_for_a_full_page_show_frame
    assert_nil show_link_url_params_for("_top")
  end

  def test_no_params_when_no_show_frame_override_grid_and_table
    assert_nil show_link_url_params_for(nil)
  end

  private

  def show_link_url_params_for(frame)
    definition = Object.new
    definition.define_singleton_method(:defined_grid_fields) { {} }
    Plutonium::UI::Grid::Card.new(
      Struct.new(:id).new(1), resource_definition: definition, show_turbo_frame: frame
    ).send(:show_link_url_params)
  end
end

# Unit tests for Grid::Card#render_show_link — the hidden anchor the row-click
# controller navigates through. It renders the :show action, so the action's
# author `link:` bag must merge over the framework's attributes here just like
# on the table's Show button (author wins on collision).
class Plutonium::UI::Grid::CardShowLinkTest < Minitest::Test
  def test_show_link_merges_the_show_actions_link_bag
    show = Plutonium::Action::Simple.new(:show, link: {target: "_blank", data: {analytics: "open"}})
    attrs = capture_show_link(show)

    assert_equal "_blank", attrs[:target]
    assert_equal "open", attrs[:data][:analytics]
    # framework-managed data survives alongside the author keys
    assert_equal "show", attrs[:data][:row_click_target]
  end

  def test_show_link_author_wins_on_framework_key_collision
    show = Plutonium::Action::Simple.new(:show, link: {class: "custom", data: {row_click_target: "none"}})
    attrs = capture_show_link(show)

    assert_equal "custom", attrs[:class]
    assert_equal "none", attrs[:data][:row_click_target]
  end

  def test_show_link_without_bag_keeps_framework_attributes
    show = Plutonium::Action::Simple.new(:show)
    attrs = capture_show_link(show)

    assert_equal "/things/1", attrs[:href]
    assert_equal "sr-only", attrs[:class]
    assert_equal "Open Thing", attrs[:"aria-label"]
  end

  private

  # Invokes the private render with the terminal `a` helper stubbed to
  # capture the exact attribute hash the render path passed to it.
  def capture_show_link(show_action)
    definition = Object.new
    definition.define_singleton_method(:defined_actions) { {show: show_action} }
    definition.define_singleton_method(:show_in) { :page }

    card = Plutonium::UI::Grid::Card.new(
      Struct.new(:id).new(1), resource_definition: definition
    )
    captured = nil
    card.define_singleton_method(:route_options_to_url) { |*| "/things/1" }
    card.define_singleton_method(:merge_query_params) { |url, _params| url }
    card.define_singleton_method(:header_text) { "Thing" }
    card.define_singleton_method(:a) do |**attrs, &_blk|
      captured = attrs
      nil
    end
    card.send(:render_show_link)
    captured
  end
end

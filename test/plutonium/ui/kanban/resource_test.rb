# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Kanban::ResourceTest < Minitest::Test
  # ---------------------------------------------------------------------------
  # column_frame_id
  # ---------------------------------------------------------------------------

  def test_column_frame_id_uses_kanban_col_prefix
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    assert_equal "kanban-col-todo", resource.send(:column_frame_id, col)
  end

  def test_column_frame_id_uses_column_key
    col = build_col(:in_progress)
    resource = build_resource(columns: [col])
    assert_equal "kanban-col-in_progress", resource.send(:column_frame_id, col)
  end

  # ---------------------------------------------------------------------------
  # column_frame_src
  # ---------------------------------------------------------------------------

  def test_column_frame_src_contains_view_kanban
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/tasks", query_params: {})
    src = resource.send(:column_frame_src, col)
    assert_match(/view=kanban/, src)
  end

  def test_column_frame_src_contains_column_key
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/tasks", query_params: {})
    src = resource.send(:column_frame_src, col)
    assert_match(/column=todo/, src)
  end

  def test_column_frame_src_uses_request_path
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/admin/tasks", query_params: {})
    src = resource.send(:column_frame_src, col)
    assert src.start_with?("/admin/tasks?")
  end

  def test_column_frame_src_preserves_existing_query_params
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/tasks", query_params: {"scope" => "active"})
    src = resource.send(:column_frame_src, col)
    assert_match(/scope=active/, src)
    assert_match(/view=kanban/, src)
    assert_match(/column=todo/, src)
  end

  def test_column_frame_src_overrides_view_param
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/tasks", query_params: {"view" => "table"})
    src = resource.send(:column_frame_src, col)
    # view=kanban should override the existing view=table
    assert_match(/view=kanban/, src)
    refute_match(/view=table/, src)
  end

  # ---------------------------------------------------------------------------
  # view_template — frame ids and attributes
  # ---------------------------------------------------------------------------

  def test_renders_one_frame_per_column
    cols = [build_col(:todo), build_col(:doing), build_col(:done)]
    resource = build_resource(columns: cols)
    stub_request(resource, path: "/tasks", query_params: {})

    frame_ids = []
    resource.define_singleton_method(:turbo_frame_tag) do |id, **_attrs, &block|
      frame_ids << id
      block&.call
    end
    resource.define_singleton_method(:render_column_header) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }

    resource.call

    assert_equal ["kanban-col-todo", "kanban-col-doing", "kanban-col-done"], frame_ids
  end

  def test_lazy_loading_attr_present_when_board_lazy
    col = build_col(:todo)
    resource = build_resource(columns: [col], lazy: true)
    stub_request(resource, path: "/tasks", query_params: {})

    captured = {}
    resource.define_singleton_method(:turbo_frame_tag) do |id, **attrs, &block|
      captured.merge!(id: id, attrs: attrs)
      block&.call
    end
    resource.define_singleton_method(:render_column_header) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }

    resource.call

    assert_equal "lazy", captured[:attrs][:loading]
  end

  def test_no_lazy_attr_when_board_not_lazy
    col = build_col(:todo)
    resource = build_resource(columns: [col], lazy: false)
    stub_request(resource, path: "/tasks", query_params: {})

    captured = {}
    resource.define_singleton_method(:turbo_frame_tag) do |id, **attrs, &block|
      captured.merge!(id: id, attrs: attrs)
      block&.call
    end
    resource.define_singleton_method(:render_column_header) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }

    resource.call

    refute captured[:attrs].key?(:loading), "loading attr should be absent when board.lazy? is false"
  end

  def test_frame_src_contains_view_and_column_params
    col = build_col(:todo)
    resource = build_resource(columns: [col], lazy: true)
    stub_request(resource, path: "/tasks", query_params: {})

    captured = {}
    resource.define_singleton_method(:turbo_frame_tag) do |id, **attrs, &block|
      captured.merge!(id: id, attrs: attrs)
      block&.call
    end
    resource.define_singleton_method(:render_column_header) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }

    resource.call

    assert_match(/view=kanban/, captured[:attrs][:src])
    assert_match(/column=todo/, captured[:attrs][:src])
  end

  # ---------------------------------------------------------------------------
  # view_template — wrapper element
  # ---------------------------------------------------------------------------

  def test_wrapper_has_kanban_controller
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    # Stub render_column_frame so no view_context calls happen; we only want
    # to check the outer wrapper element.
    resource.define_singleton_method(:render_column_frame) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }
    stub_kanban_move_url_template(resource)
    stub_toolbar(resource)

    html = resource.call

    assert_match(/data-controller="kanban"/, html)
  end

  def test_wrapper_has_move_url_template_value
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    resource.define_singleton_method(:render_column_frame) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }
    stub_request(resource, path: "/admin/tasks", query_params: {})

    html = resource.call

    assert_match(/data-kanban-move-url-template-value=/, html)
  end

  def test_move_url_template_contains_id_placeholder
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    resource.define_singleton_method(:render_column_frame) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }
    stub_request(resource, path: "/admin/tasks", query_params: {})

    html = resource.call

    assert_match(/__ID__/, html)
    assert_match(%r{__ID__/kanban_move}, html)
  end

  def test_move_url_template_uses_request_path
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    resource.define_singleton_method(:render_column_frame) { |_col| }
    resource.define_singleton_method(:render_realtime_subscription) { }
    stub_request(resource, path: "/admin/tasks", query_params: {})

    html = resource.call

    assert_match(%r{/admin/tasks/__ID__/kanban_move}, html)
  end

  def test_kanban_move_url_template_method
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/admin/tasks", query_params: {})

    assert_equal "/admin/tasks/__ID__/kanban_move", resource.send(:kanban_move_url_template)
  end

  def test_kanban_move_url_template_strips_trailing_slash
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/admin/tasks/", query_params: {})

    assert_equal "/admin/tasks/__ID__/kanban_move", resource.send(:kanban_move_url_template)
  end

  # ---------------------------------------------------------------------------
  # column headers inside the frame
  # ---------------------------------------------------------------------------

  def test_column_header_contains_column_label
    col = build_col(:todo)
    resource = build_resource(columns: [col])
    stub_request(resource, path: "/tasks", query_params: {})
    # Stub turbo_frame_tag to execute the block so the header HTML is captured.
    resource.define_singleton_method(:turbo_frame_tag) { |_id, **_attrs, &block| block&.call }
    resource.define_singleton_method(:render_realtime_subscription) { }

    html = resource.call

    assert_match(/Todo/, html, "column label should appear in header")
  end

  # The shell header deliberately renders NO card-count badge: the shell has no
  # card data, so a count would flash (e.g. "0") then disappear when
  # Kanban::Column — which renders no count badge either — replaces the frame
  # body. This guards that structural consistency.
  def test_column_header_omits_card_count_badge
    col = build_col(:todo)
    resource = build_resource(columns: [col], cards: [stub_record, stub_record])
    stub_request(resource, path: "/tasks", query_params: {})
    resource.define_singleton_method(:turbo_frame_tag) { |_id, **_attrs, &block| block&.call }
    resource.define_singleton_method(:render_realtime_subscription) { }

    html = resource.call

    refute_match(/pu-badge/, html, "shell header should not render a count badge")
  end

  # ---------------------------------------------------------------------------
  # realtime? hook
  # ---------------------------------------------------------------------------

  def test_realtime_subscription_called_when_realtime
    col = build_col(:todo)
    resource = build_resource(columns: [col], realtime: true)
    resource.define_singleton_method(:render_column_frame) { |_col| }
    stub_kanban_move_url_template(resource)
    stub_toolbar(resource)

    called = false
    resource.define_singleton_method(:render_realtime_subscription) { called = true }

    resource.call

    assert called, "render_realtime_subscription should be called when board.realtime? is true"
  end

  def test_realtime_subscription_not_called_when_not_realtime
    col = build_col(:todo)
    resource = build_resource(columns: [col], realtime: false)
    resource.define_singleton_method(:render_column_frame) { |_col| }
    stub_kanban_move_url_template(resource)
    stub_toolbar(resource)

    called = false
    resource.define_singleton_method(:render_realtime_subscription) { called = true }

    resource.call

    refute called, "render_realtime_subscription should not be called when board.realtime? is false"
  end

  private

  def build_col(key, **opts)
    Plutonium::Kanban::Column.new(key, **opts)
  end

  def build_board(columns:, lazy: true, realtime: false)
    Plutonium::Kanban::Board.new(
      columns: columns,
      columns_block: nil,
      card_fields: nil,
      per_column: 10,
      realtime: realtime,
      position_config: Plutonium::Kanban::Positioning::Config.disabled,
      lazy: lazy
    )
  end

  def build_resource(columns:, lazy: true, realtime: false, cards: [])
    board = build_board(columns: columns, lazy: lazy, realtime: realtime)
    grouped = columns.map { |col| {column: col, cards: cards, total: cards.size} }

    Plutonium::UI::Kanban::Resource.new(
      board: board,
      grouped_data: grouped,
      resource_definition: nil,
      resource_fields: []
    )
  end

  def stub_request(component, path:, query_params:)
    fake_request = Struct.new(:path, :query_parameters).new(path, query_params)
    component.define_singleton_method(:request) { fake_request }
    stub_toolbar(component)
  end

  # The shared toolbar (view switcher / search / filters) needs controller
  # context (current_query_object, TableToolbar, …) that isn't present in these
  # isolated component tests. It's covered by the kanban integration tests; here
  # we stub it so the board/column-frame assertions can run.
  def stub_toolbar(component)
    fake_query = Struct.new(:filter_definitions, :scope_definitions).new([], [])
    component.define_singleton_method(:current_query_object) { fake_query }
    component.define_singleton_method(:render_scopes_pills) { }
    component.define_singleton_method(:render_toolbar) { }
  end

  # Stubs out kanban_move_url_template so tests that don't care about URL
  # generation don't need a full request stub.
  def stub_kanban_move_url_template(component, template: "/tasks/__ID__/kanban_move")
    component.define_singleton_method(:kanban_move_url_template) { template }
  end

  def stub_record
    Struct.new(:id).new(SecureRandom.random_number(1000))
  end
end

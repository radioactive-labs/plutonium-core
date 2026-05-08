# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/table/components/filter_pills"

class Plutonium::UI::Table::Components::FilterPillsTest < Minitest::Test
  class MockResource
    def self.search(query) = "searched: #{query}"
    def self.primary_key = "id"
    def self.content_column_field_names = [:title, :status]
    def self.belongs_to_association_field_names = []
    def self.column_names = %w[id title status]
  end

  # ==================== Rendering condition tests ====================

  def test_renders_nothing_when_no_filters_and_zero_count
    html = build_component(params: {}, filters: [:status], total_count: 0).call
    assert_empty html
  end

  def test_renders_nothing_when_no_filters_and_nil_count
    html = build_component(params: {}, filters: [:status], total_count: nil).call
    assert_empty html
  end

  def test_renders_strip_when_filters_active_and_zero_count
    html = build_component(params: {status: {query: "active"}}, filters: [:status], total_count: 0).call
    refute_empty html
  end

  def test_renders_strip_when_no_filters_but_positive_count
    html = build_component(params: {}, filters: [:status], total_count: 5).call
    refute_empty html
  end

  # ==================== Filter pill rendering ====================

  def test_renders_pill_for_each_active_filter
    html = build_component(params: {status: {query: "active"}, title: {query: "hello"}},
      filters: [:status, :title], total_count: nil).call
    # Two pills — one per active filter
    assert_equal 2, html.scan(/Remove \w+ filter/).length
  end

  def test_pill_contains_label_and_value
    html = build_component(params: {status: {query: "active"}}, filters: [:status], total_count: nil).call
    assert_includes html, "Status:"
    assert_includes html, "active"
  end

  def test_pill_has_remove_link_with_correct_aria_label
    html = build_component(params: {status: {query: "active"}}, filters: [:status], total_count: nil).call
    assert_match(/aria-label="Remove Status filter"/, html)
  end

  def test_pill_remove_link_points_to_clear_url
    html = build_component(params: {status: {query: "active"}}, filters: [:status], total_count: nil).call
    # The clear URL should NOT contain the status param
    assert_match(/href="[^"]*"/, html)
    # The href should not include status filter param
    href = html.match(/aria-label="Remove Status filter".*?<\/a>/m)&.pre_match&.match(/href="([^"]+)"/)&.[](1)
    refute_nil href
    refute_match(/status/, href)
  end

  # ==================== Add filter pill ====================

  def test_renders_add_filter_pill_when_filters_active
    html = build_component(params: {status: {query: "active"}}, filters: [:status], total_count: nil).call
    assert_includes html, "filter-panel#toggle"
    assert_includes html, "Filter"
  end

  def test_does_not_render_add_filter_pill_when_no_filters_active
    html = build_component(params: {}, filters: [:status], total_count: 5).call
    refute_includes html, "filter-panel#toggle"
  end

  # ==================== Result count ====================

  def test_renders_result_count_plural
    html = build_component(params: {}, filters: [:status], total_count: 147).call
    assert_includes html, "147 results"
  end

  def test_renders_result_count_singular
    html = build_component(params: {}, filters: [:status], total_count: 1).call
    assert_includes html, "1 result"
    refute_includes html, "1 results"
  end

  def test_does_not_render_result_count_when_nil
    html = build_component(params: {status: {query: "active"}}, filters: [:status], total_count: nil).call
    refute_match(/\d+ results?/, html)
  end

  # ==================== Only result count, no filters ====================

  def test_renders_only_count_when_no_filters_active_but_count_positive
    html = build_component(params: {}, filters: [:status], total_count: 10).call
    assert_includes html, "10 results"
    refute_includes html, "filter-panel#toggle"
  end

  private

  def build_component(params:, filters:, total_count:)
    query_object = Plutonium::Resource::QueryObject.new(MockResource, params, "/posts") do |qo|
      filters.each do |f|
        qo.define_filter(f, ->(scope, query:) { scope.where(f => query) })
      end
    end

    component = Plutonium::UI::Table::Components::FilterPills.allocate
    component.instance_variable_set(:@_context, {})
    component.instance_variable_set(:@query, query_object)
    component.instance_variable_set(:@total_count, total_count)

    component
  end
end

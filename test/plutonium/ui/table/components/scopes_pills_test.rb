# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/table/components/scopes_pills"

class Plutonium::UI::Table::Components::ScopesPillsTest < Minitest::Test
  class MockResource
    def self.search(query) = "searched: #{query}"
    def self.published = "published_scope"
    def self.draft = "draft_scope"
    def self.featured = "featured_scope"
    def self.primary_key = "id"
    def self.content_column_field_names = [:title]
    def self.belongs_to_association_field_names = []
    def self.column_names = %w[id title]
  end

  def test_renders_nothing_when_no_scopes_defined
    component = build_component(params: {}, default_scope: nil, scopes: [])
    assert_empty component.call
  end

  def test_renders_all_pill_plus_one_per_scope
    html = build_component(params: {}, default_scope: nil, scopes: [:published, :draft]).call
    assert_equal 3, html.scan(/<a/).length
    assert_includes html, ">All<"
    assert_includes html, "Published"
    assert_includes html, "Draft"
  end

  def test_active_scope_has_primary_classes
    html = build_component(params: {scope: "published"}, default_scope: nil, scopes: [:published, :draft]).call
    assert_match(/id="published-scope"[^>]*class="[^"]*bg-primary-100[^"]*"/, html)
  end

  def test_inactive_scope_has_hover_classes
    html = build_component(params: {scope: "published"}, default_scope: nil, scopes: [:published, :draft]).call
    assert_match(/id="draft-scope"[^>]*class="[^"]*hover:bg-\[var\(--pu-surface-alt\)\][^"]*"/, html)
  end

  def test_all_pill_active_when_no_scope_and_no_default
    html = build_component(params: {}, default_scope: nil, scopes: [:published, :draft]).call
    assert_match(/id="all-scope"[^>]*class="[^"]*bg-primary-100[^"]*"/, html)
  end

  def test_all_pill_active_when_explicitly_selected
    html = build_component(params: {scope: ""}, default_scope: :published, scopes: [:published, :draft]).call
    assert_match(/id="all-scope"[^>]*class="[^"]*bg-primary-100[^"]*"/, html)
  end

  def test_default_scope_active_when_no_param
    html = build_component(params: {}, default_scope: :published, scopes: [:published, :draft]).call
    assert_match(/id="published-scope"[^>]*class="[^"]*bg-primary-100[^"]*"/, html)
    assert_match(/id="all-scope"[^>]*class="[^"]*hover:bg-\[var\(--pu-surface-alt\)\][^"]*"/, html)
  end

  def test_scope_urls_contain_correct_scope_param
    html = build_component(params: {}, default_scope: nil, scopes: [:published, :draft]).call
    assert_match(/id="published-scope"[^>]*href="[^"]*scope%5D=published"/, html)
    assert_match(/id="draft-scope"[^>]*href="[^"]*scope%5D=draft"/, html)
    assert_match(/id="all-scope"[^>]*href="[^"]*scope%5D="/, html)
  end

  def test_renders_nav_with_tablist_role
    html = build_component(params: {}, default_scope: nil, scopes: [:published]).call
    assert_match(/role="tablist"/, html)
  end

  def test_each_pill_has_tab_role
    html = build_component(params: {}, default_scope: nil, scopes: [:published, :draft]).call
    assert_equal 3, html.scan(/role="tab"/).length
  end

  def test_active_pill_has_aria_selected
    html = build_component(params: {scope: "draft"}, default_scope: nil, scopes: [:published, :draft]).call
    # Only one pill should be aria-selected (the active one)
    # Phlex renders aria-selected as a boolean attribute when true
    selected = html.scan(/aria-selected/).length
    assert_equal 1, selected
  end

  private

  def build_component(params:, default_scope:, scopes:)
    query_object = Plutonium::Resource::QueryObject.new(MockResource, params, "/posts") do |qo|
      scopes.each { |s| qo.define_scope s }
      qo.default_scope_name = default_scope if default_scope
    end

    component = Plutonium::UI::Table::Components::ScopesPills.allocate
    component.instance_variable_set(:@_context, {})

    component.define_singleton_method(:current_query_object) { query_object }
    component.define_singleton_method(:raw_resource_query_params) { params }

    component
  end
end

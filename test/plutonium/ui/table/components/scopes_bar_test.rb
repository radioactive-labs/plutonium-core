# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/table/components/scopes_bar"

class Plutonium::UI::Table::Components::ScopesBarTest < Minitest::Test
  # Mock resource class
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

  def test_default_scope_is_active_without_url_param
    component = build_component(
      params: {},
      default_scope: :published,
      scopes: [:published, :draft]
    )

    html = component.call

    assert_scope_active(html, "published")
    assert_scope_inactive(html, "draft")
    assert_all_scope_inactive(html)
  end

  def test_explicit_scope_param_is_active
    component = build_component(
      params: {scope: "draft"},
      default_scope: :published,
      scopes: [:published, :draft]
    )

    html = component.call

    assert_scope_active(html, "draft")
    assert_scope_inactive(html, "published")
    assert_all_scope_inactive(html)
  end

  def test_symbol_scope_param_is_active
    component = build_component(
      params: {scope: :draft},
      default_scope: :published,
      scopes: [:published, :draft]
    )

    html = component.call

    assert_scope_active(html, "draft")
    assert_scope_inactive(html, "published")
    assert_all_scope_inactive(html)
  end

  def test_all_scope_active_when_explicitly_selected
    component = build_component(
      params: {scope: ""},
      default_scope: :published,
      scopes: [:published, :draft]
    )

    html = component.call

    assert_all_scope_active(html)
    assert_scope_inactive(html, "published")
    assert_scope_inactive(html, "draft")
  end

  def test_all_scope_active_when_no_default_and_no_param
    component = build_component(
      params: {},
      default_scope: nil,
      scopes: [:published, :draft]
    )

    html = component.call

    assert_all_scope_active(html)
    assert_scope_inactive(html, "published")
    assert_scope_inactive(html, "draft")
  end

  def test_scope_buttons_have_correct_urls
    component = build_component(
      params: {},
      default_scope: :published,
      scopes: [:published, :draft]
    )

    html = component.call

    assert_match(/id="all-scope"[^>]*href="[^"]*scope%5D="/, html,
      "Expected 'All' scope button to have a URL with empty scope")
    assert_match(/id="published-scope"[^>]*href="[^"]*scope%5D=published"/, html,
      "Expected 'published' scope button URL to contain scope=published")
    assert_match(/id="draft-scope"[^>]*href="[^"]*scope%5D=draft"/, html,
      "Expected 'draft' scope button URL to contain scope=draft")
  end

  def test_scope_buttons_display_humanized_labels
    component = build_component(
      params: {},
      default_scope: nil,
      scopes: [:published, :featured]
    )

    html = component.call

    assert_includes html, "Published"
    assert_includes html, "Featured"
    assert_includes html, "All"
  end

  def test_does_not_render_without_scopes
    component = build_component(
      params: {},
      default_scope: nil,
      scopes: []
    )

    html = component.call

    assert_empty html
  end

  private

  def build_component(params:, default_scope:, scopes:)
    query_object = Plutonium::Resource::QueryObject.new(MockResource, params, "/posts") do |qo|
      scopes.each { |s| qo.define_scope s }
      qo.default_scope_name = default_scope if default_scope
    end

    component = Plutonium::UI::Table::Components::ScopesBar.allocate
    component.instance_variable_set(:@_context, {})

    # Stub the helper methods the component depends on
    component.define_singleton_method(:current_query_object) { query_object }
    component.define_singleton_method(:raw_resource_query_params) { params }

    component
  end

  def assert_scope_active(html, scope_name)
    assert_match(/id="#{scope_name}-scope"[^>]*class="[^"]*pu-btn-primary[^"]*"/, html,
      "Expected '#{scope_name}' scope to be active (pu-btn-primary)")
  end

  def assert_scope_inactive(html, scope_name)
    assert_match(/id="#{scope_name}-scope"[^>]*class="[^"]*pu-btn-ghost[^"]*"/, html,
      "Expected '#{scope_name}' scope to be inactive (pu-btn-ghost)")
  end

  def assert_all_scope_active(html)
    assert_match(/id="all-scope"[^>]*class="[^"]*pu-btn-primary[^"]*"/, html,
      "Expected 'All' scope to be active (pu-btn-primary)")
  end

  def assert_all_scope_inactive(html)
    assert_match(/id="all-scope"[^>]*class="[^"]*pu-btn-ghost[^"]*"/, html,
      "Expected 'All' scope to be inactive (pu-btn-ghost)")
  end
end

# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::ResourceTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Minimal definition stub that satisfies render_resource_field
  FakeDefinition = Struct.new(:defined_fields, :defined_displays) do
    def initialize(defined_fields: {}, defined_displays: {})
      super
    end
  end

  # Build a Resource instance without requiring a full Phlexi render context.
  # We stub out everything that touches rendering so tests can interrogate
  # the private routing logic directly.
  def build_resource(resource_associations: [], present_associations: true, registered: [])
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [],
      resource_associations: resource_associations,
      resource_definition: definition
    )

    # Control the turbo-frame predicate
    component.define_singleton_method(:present_associations?) { present_associations }

    # Stub rendering primitives that need a real Phlexi context
    component.define_singleton_method(:render_fields) { :fields_rendered }
    component.define_singleton_method(:render_tablist_with_details) { :tablist_rendered }

    component
  end

  # ---------------------------------------------------------------------------
  # associations_present?
  # ---------------------------------------------------------------------------

  test "associations_present? is false when resource_associations is empty" do
    component = build_resource(resource_associations: [], present_associations: true)
    refute component.send(:associations_present?)
  end

  test "associations_present? is false when present_associations? is false" do
    component = build_resource(resource_associations: [:widgets], present_associations: false)
    refute component.send(:associations_present?)
  end

  test "associations_present? is true when associations present and not in turbo frame" do
    component = build_resource(resource_associations: [:widgets], present_associations: true)
    assert component.send(:associations_present?)
  end

  # ---------------------------------------------------------------------------
  # display_template routing
  # ---------------------------------------------------------------------------

  test "display_template calls render_fields when no associations" do
    component = build_resource(resource_associations: [], present_associations: true)
    called = []
    component.define_singleton_method(:render_fields) { called << :render_fields }
    component.define_singleton_method(:render_tablist_with_details) { called << :render_tablist_with_details }

    component.display_template

    assert_equal [:render_fields], called
  end

  test "display_template calls render_fields when in turbo frame context" do
    component = build_resource(resource_associations: [:widgets], present_associations: false)
    called = []
    component.define_singleton_method(:render_fields) { called << :render_fields }
    component.define_singleton_method(:render_tablist_with_details) { called << :render_tablist_with_details }

    component.display_template

    assert_equal [:render_fields], called
  end

  test "display_template calls render_tablist_with_details when associations present and not in frame" do
    component = build_resource(resource_associations: [:widgets], present_associations: true)
    called = []
    component.define_singleton_method(:render_fields) { called << :render_fields }
    component.define_singleton_method(:render_tablist_with_details) { called << :render_tablist_with_details }

    component.display_template

    assert_equal [:render_tablist_with_details], called
  end

  # ---------------------------------------------------------------------------
  # render_tablist_with_details — tab building logic
  # ---------------------------------------------------------------------------

  test "render_tablist_with_details adds Details as first tab" do
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [:name],
      resource_associations: [:widgets],
      resource_definition: definition
    )
    component.define_singleton_method(:present_associations?) { true }

    tabs_added = []
    fake_tablist = Object.new
    fake_tablist.define_singleton_method(:with_tab) { |identifier:, title:, &block| tabs_added << {identifier: identifier, title: title, block: block} }

    component.define_singleton_method(:BuildTabList) { fake_tablist }
    component.define_singleton_method(:render_fields) { :fields }
    component.define_singleton_method(:registered_resources) { [Widget] }
    component.define_singleton_method(:association_src) { |_name, _reflection| "/widgets" }
    component.define_singleton_method(:FrameNavigatorPanel) { |**_kwargs| nil }
    component.define_singleton_method(:render) { |_tablist| nil }

    component.send(:render_tablist_with_details)

    assert tabs_added.length >= 1, "at least one tab should be added"
    assert_equal "details", tabs_added.first[:identifier]
  end

  test "render_tablist_with_details adds association tab after Details" do
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [:name],
      resource_associations: [:widgets],
      resource_definition: definition
    )
    component.define_singleton_method(:present_associations?) { true }

    tabs_added = []
    fake_tablist = Object.new
    fake_tablist.define_singleton_method(:with_tab) { |identifier:, title:, &block| tabs_added << {identifier: identifier, title: title, block: block} }

    component.define_singleton_method(:BuildTabList) { fake_tablist }
    component.define_singleton_method(:render_fields) { :fields }
    component.define_singleton_method(:registered_resources) { [Widget] }
    component.define_singleton_method(:association_src) { |_name, _reflection| "/widgets" }
    component.define_singleton_method(:FrameNavigatorPanel) { |**_kwargs| nil }
    component.define_singleton_method(:render) { |_tablist| nil }

    component.send(:render_tablist_with_details)

    # Should have Details tab + widgets tab
    assert_equal 2, tabs_added.length
    assert_equal "details", tabs_added[0][:identifier]
    # "widgets" humanized and parameterized
    assert_equal Organization.human_attribute_name(:widgets).parameterize, tabs_added[1][:identifier]
  end

  test "render_tablist_with_details skips association tab when src is nil" do
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [:name],
      resource_associations: [:widgets],
      resource_definition: definition
    )
    component.define_singleton_method(:present_associations?) { true }

    tabs_added = []
    fake_tablist = Object.new
    fake_tablist.define_singleton_method(:with_tab) { |identifier:, title:, &block| tabs_added << {identifier: identifier, title: title, block: block} }

    component.define_singleton_method(:BuildTabList) { fake_tablist }
    component.define_singleton_method(:render_fields) { :fields }
    component.define_singleton_method(:registered_resources) { [Widget] }
    # src is nil → association tab should be skipped
    component.define_singleton_method(:association_src) { |_name, _reflection| nil }
    component.define_singleton_method(:render) { |_tablist| nil }

    component.send(:render_tablist_with_details)

    # Only the Details tab should have been added
    assert_equal 1, tabs_added.length
    assert_equal "details", tabs_added.first[:identifier]
  end

  test "render_tablist_with_details omits Details tab when no fields are permitted" do
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [],
      resource_associations: [:widgets],
      resource_definition: definition
    )
    component.define_singleton_method(:present_associations?) { true }

    tabs_added = []
    fake_tablist = Object.new
    fake_tablist.define_singleton_method(:with_tab) { |identifier:, title:, &block| tabs_added << {identifier: identifier, title: title, block: block} }

    component.define_singleton_method(:BuildTabList) { fake_tablist }
    component.define_singleton_method(:render_fields) { :fields }
    component.define_singleton_method(:registered_resources) { [Widget] }
    component.define_singleton_method(:association_src) { |_name, _reflection| "/widgets" }
    component.define_singleton_method(:FrameNavigatorPanel) { |**_kwargs| nil }
    component.define_singleton_method(:render) { |_tablist| nil }

    component.send(:render_tablist_with_details)

    # No Details tab — only the association tab leads.
    assert_equal 1, tabs_added.length
    assert_equal Organization.human_attribute_name(:widgets).parameterize, tabs_added.first[:identifier]
  end

  test "render_tablist_with_details raises on unknown association" do
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [],
      resource_associations: [:nonexistent_relation],
      resource_definition: definition
    )
    component.define_singleton_method(:present_associations?) { true }

    fake_tablist = Object.new
    fake_tablist.define_singleton_method(:with_tab) { |**_kwargs, &_block| }

    component.define_singleton_method(:BuildTabList) { fake_tablist }
    component.define_singleton_method(:render_fields) { :fields }

    assert_raises(ArgumentError) do
      component.send(:render_tablist_with_details)
    end
  end

  test "render_tablist_with_details raises when association class is not a registered resource" do
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [],
      resource_associations: [:widgets],
      resource_definition: definition
    )
    component.define_singleton_method(:present_associations?) { true }

    fake_tablist = Object.new
    fake_tablist.define_singleton_method(:with_tab) { |**_kwargs, &_block| }

    component.define_singleton_method(:BuildTabList) { fake_tablist }
    component.define_singleton_method(:render_fields) { :fields }
    # Registered resources list does NOT include Widget
    component.define_singleton_method(:registered_resources) { [] }

    assert_raises(ArgumentError) do
      component.send(:render_tablist_with_details)
    end
  end

  # ---------------------------------------------------------------------------
  # association_src
  # ---------------------------------------------------------------------------

  test "association_src for has_many returns resource_url_for with parent" do
    obj = Organization.new(name: "Acme")
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [],
      resource_associations: [],
      resource_definition: definition
    )

    reflection = Organization.reflect_on_association(:widgets)
    url_args = nil
    url_kwargs = nil
    component.define_singleton_method(:resource_url_for) do |klass, **kwargs|
      url_args = klass
      url_kwargs = kwargs
      "/widgets"
    end

    result = component.send(:association_src, :widgets, reflection)

    assert_equal "/widgets", result
    assert_equal Widget, url_args
    assert_equal obj, url_kwargs[:parent]
    assert_equal :widgets, url_kwargs[:association]
  end

  test "association_src for belongs_to returns nil when associated record is nil" do
    obj = Widget.new
    definition = FakeDefinition.new

    component = Plutonium::UI::Display::Resource.new(
      obj,
      resource_fields: [],
      resource_associations: [],
      resource_definition: definition
    )

    reflection = Widget.reflect_on_association(:organization)
    assert_nil component.send(:association_src, :organization, reflection)
  end
end

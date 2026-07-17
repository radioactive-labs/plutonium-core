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
  # render_before_fields / render_after_fields hooks
  # ---------------------------------------------------------------------------

  def build_hookable(resource_fields: [:name])
    component = Plutonium::UI::Display::Resource.new(
      Organization.new(name: "Acme"),
      resource_fields: resource_fields,
      resource_associations: [],
      resource_definition: FakeDefinition.new
    )
    component.define_singleton_method(:present_associations?) { true }
    component
  end

  test "render_fields is a no-op wrapper around the fields when hooks are not overridden" do
    component = build_hookable
    called = []
    component.define_singleton_method(:render_default_fields) { called << :default_fields }

    component.send(:render_fields)

    assert_equal [:default_fields], called
  end

  test "render_fields renders hooks around the fields in order" do
    component = build_hookable
    called = []
    component.define_singleton_method(:render_before_fields) { called << :before }
    component.define_singleton_method(:render_default_fields) { called << :default_fields }
    component.define_singleton_method(:render_after_fields) { called << :after }

    component.send(:render_fields)

    assert_equal [:before, :default_fields, :after], called
  end

  test "Details tab body routes through the outer display's render_fields so hooks fire" do
    component = build_hookable
    called = []
    component.define_singleton_method(:render_fields) { called << :render_fields }

    details_display = component.send(:build_details_display)
    details_display.view_template

    assert_equal [:render_fields], called
  end

  # ---------------------------------------------------------------------------
  # render_default_fields — metadata panel routing
  # ---------------------------------------------------------------------------

  # Stub the Phlex kit methods render_default_fields uses so we can exercise its
  # branching without a live render context, and record which slots it renders.
  def build_metadata_component(metadata_fields:, in_kanban_modal:)
    component = build_resource
    component.define_singleton_method(:metadata_fields) { metadata_fields }
    component.define_singleton_method(:in_kanban_modal?) { in_kanban_modal }
    component.define_singleton_method(:div) { |*a, **k, &b| b&.call }
    component.define_singleton_method(:aside) { |*a, **k, &b| b&.call }
    component
  end

  test "render_default_fields renders the metadata panel when metadata present and not in a kanban modal" do
    component = build_metadata_component(metadata_fields: [:created_at], in_kanban_modal: false)
    called = []
    component.define_singleton_method(:render_main_field_card) { called << :main }
    component.define_singleton_method(:render_metadata_panel) { called << :panel }

    component.send(:render_default_fields)

    assert_equal [:main, :panel], called
  end

  test "render_default_fields omits the metadata panel inside a kanban modal" do
    component = build_metadata_component(metadata_fields: [:created_at], in_kanban_modal: true)
    called = []
    component.define_singleton_method(:render_main_field_card) { called << :main }
    component.define_singleton_method(:render_metadata_panel) { called << :panel }

    component.send(:render_default_fields)

    assert_equal [:main], called, "metadata panel should be skipped in a kanban modal"
  end

  test "render_default_fields renders only the main card when no metadata declared" do
    component = build_metadata_component(metadata_fields: [], in_kanban_modal: false)
    called = []
    component.define_singleton_method(:render_main_field_card) { called << :main }
    component.define_singleton_method(:render_metadata_panel) { called << :panel }

    component.send(:render_default_fields)

    assert_equal [:main], called
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

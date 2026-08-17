# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::DisplayLayoutTest < Minitest::Test
  def build_definition(&block)
    Class.new(Plutonium::Definition::Base, &block)
  end

  def test_records_sections_in_order_with_options
    klass = build_definition do
      display_layout do
        section :identity, :name, :email, label: "Your identification"
        section :address, :street, :city, collapsible: true
      end
    end

    layout = klass.defined_display_layout
    assert_equal %i[identity address], layout.map(&:key)
    assert_equal %i[name email], layout.first.fields
    assert_equal "Your identification", layout.first.label
    assert layout.last.collapsible?
  end

  def test_section_label_defaults_to_humanized_key
    klass = build_definition { display_layout { section :billing_address, :street } }
    assert_equal "Billing address", klass.defined_display_layout.first.label
  end

  def test_ungrouped_macro_is_recorded_with_its_position
    klass = build_definition do
      display_layout do
        section :a, :x
        ungrouped label: "Other"
      end
    end
    layout = klass.defined_display_layout
    assert_equal %i[a ungrouped], layout.map(&:key)
    assert layout.last.ungrouped?
    assert_empty layout.last.fields
  end

  def test_section_ungrouped_key_raises
    error = assert_raises(ArgumentError) do
      build_definition { display_layout { section :ungrouped, :x } }
    end
    assert_match(/reserved/, error.message)
  end

  def test_duplicate_ungrouped_raises
    assert_raises(ArgumentError) do
      build_definition {
        display_layout {
          ungrouped
          ungrouped
        }
      }
    end
  end

  def test_display_layout_requires_a_block
    assert_raises(ArgumentError) { build_definition { display_layout } }
  end

  def test_no_layout_returns_nil
    klass = build_definition {}
    assert_nil klass.defined_display_layout
    assert_nil klass.new.defined_display_layout
  end

  def test_subclasses_inherit_layout
    parent = build_definition { display_layout { section :a, :x } }
    child = Class.new(parent)
    assert_equal %i[a], child.defined_display_layout.map(&:key)
  end

  def test_redeclaring_replaces_layout
    parent = build_definition { display_layout { section :a, :x } }
    child = Class.new(parent)
    child.display_layout { section :b, :y }
    assert_equal %i[b], child.defined_display_layout.map(&:key)
    assert_equal %i[a], parent.defined_display_layout.map(&:key)
  end

  def test_instance_exposes_layout
    klass = build_definition { display_layout { section :a, :x } }
    assert_equal %i[a], klass.new.defined_display_layout.map(&:key)
  end

  def test_registry_options_are_frozen
    klass = build_definition { display_layout { section :a, :x, label: "A" } }
    section = klass.defined_display_layout.first
    assert section.options.frozen?, "section options must be frozen (immutable registry)"
    assert_raises(FrozenError) { section.options[:label] = "nope" }
  end

  # `columns:` is form_layout-only. The display side sizes fields via
  # `display :x, wrapper: {class: "col-span-2"}`, so a section-level column
  # count would be a second way to say the same thing. Raise rather than
  # ignore, so copying a form_layout block across fails loudly.
  def test_columns_on_a_section_raises_and_points_at_the_field_pathway
    error = assert_raises(ArgumentError) do
      build_definition { display_layout { section :a, :x, columns: 2 } }
    end
    assert_match(/does not support `columns:`/, error.message)
    assert_match(/col-span-2/, error.message)
  end

  def test_columns_on_ungrouped_raises
    assert_raises(ArgumentError) do
      build_definition { display_layout { ungrouped columns: 2 } }
    end
  end

  # The same option is still perfectly valid on form_layout — rejecting it
  # here must not leak across to the form DSL.
  def test_columns_still_allowed_on_form_layout
    klass = build_definition { form_layout { section :a, :x, columns: 3 } }
    assert_equal 3, klass.defined_form_layout.first.columns
  end

  def test_sections_are_the_same_struct_type_form_layout_uses
    klass = build_definition { display_layout { section :a, :x } }
    assert_kind_of Plutonium::Definition::FormLayout::Section, klass.defined_display_layout.first
  end

  def test_form_layout_and_display_layout_are_independent
    klass = build_definition do
      form_layout { section :form_section, :x }
      display_layout { section :display_section, :x }
    end
    assert_equal %i[form_section], klass.defined_form_layout.map(&:key)
    assert_equal %i[display_section], klass.defined_display_layout.map(&:key)
  end
end

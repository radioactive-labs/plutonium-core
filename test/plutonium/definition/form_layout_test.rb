# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::FormLayoutTest < Minitest::Test
  def build_definition(&block)
    Class.new(Plutonium::Definition::Base, &block)
  end

  def test_records_sections_in_order_with_options
    klass = build_definition do
      form_layout do
        section :identity, :name, :email, label: "Your identification"
        section :address, :street, :city, collapsible: true, columns: 2
      end
    end

    layout = klass.defined_form_layout
    assert_equal %i[identity address], layout.map(&:key)
    assert_equal %i[name email], layout.first.fields
    assert_equal "Your identification", layout.first.label
    assert_equal 2, layout.last.options[:columns]
    assert layout.last.collapsible?
  end

  def test_section_label_defaults_to_humanized_key
    klass = build_definition { form_layout { section :billing_address, :street } }
    assert_equal "Billing address", klass.defined_form_layout.first.label
  end

  def test_ungrouped_macro_is_recorded_with_its_position
    klass = build_definition do
      form_layout do
        section :a, :x
        ungrouped label: "Other"
      end
    end
    layout = klass.defined_form_layout
    assert_equal %i[a ungrouped], layout.map(&:key)
    assert layout.last.ungrouped?
    assert_empty layout.last.fields
  end

  def test_section_ungrouped_key_raises
    error = assert_raises(ArgumentError) do
      build_definition { form_layout { section :ungrouped, :x } }
    end
    assert_match(/reserved/, error.message)
  end

  def test_duplicate_ungrouped_raises
    assert_raises(ArgumentError) do
      build_definition { form_layout { ungrouped; ungrouped } }
    end
  end

  def test_form_layout_requires_a_block
    assert_raises(ArgumentError) { build_definition { form_layout } }
  end

  def test_no_layout_returns_nil
    klass = build_definition {}
    assert_nil klass.defined_form_layout
    assert_nil klass.new.defined_form_layout
  end

  def test_subclasses_inherit_layout
    parent = build_definition { form_layout { section :a, :x } }
    child = Class.new(parent)
    assert_equal %i[a], child.defined_form_layout.map(&:key)
  end

  def test_redeclaring_replaces_layout
    parent = build_definition { form_layout { section :a, :x } }
    child = Class.new(parent)
    child.form_layout { section :b, :y }
    assert_equal %i[b], child.defined_form_layout.map(&:key)
    assert_equal %i[a], parent.defined_form_layout.map(&:key)
  end

  def test_instance_exposes_layout
    klass = build_definition { form_layout { section :a, :x } }
    assert_equal %i[a], klass.new.defined_form_layout.map(&:key)
  end

  def test_registry_options_are_frozen
    klass = build_definition { form_layout { section :a, :x, columns: 2 } }
    section = klass.defined_form_layout.first
    assert section.options.frozen?, "section options must be frozen (immutable registry)"
    assert_raises(FrozenError) { section.options[:columns] = 99 }
  end

  def test_label_falls_back_to_humanized_key_when_label_is_nil
    klass = build_definition { form_layout { section :billing_address, :x, label: nil } }
    assert_equal "Billing address", klass.defined_form_layout.first.label
  end

  def test_section_option_accessors
    cond = -> { true }
    klass = build_definition do
      form_layout do
        section :a, :x, description: "Desc", collapsible: true, collapsed: true,
          columns: 3, condition: cond
      end
    end
    s = klass.defined_form_layout.first
    assert_equal "Desc", s.description
    assert s.collapsible?
    assert s.collapsed?
    assert_equal 3, s.columns
    assert_equal cond, s.condition
  end

  def test_columns_zero_raises
    assert_raises(ArgumentError) do
      build_definition { form_layout { section :a, :x, columns: 0 } }
    end
  end

  def test_columns_negative_raises
    assert_raises(ArgumentError) do
      build_definition { form_layout { section :a, :x, columns: -2 } }
    end
  end

  def test_columns_string_raises
    assert_raises(ArgumentError) do
      build_definition { form_layout { section :a, :x, columns: "2" } }
    end
  end

  def test_columns_positive_integer_is_fine
    klass = build_definition { form_layout { section :a, :x, columns: 3 } }
    assert_equal 3, klass.defined_form_layout.first.columns
  end

  def test_defaults_for_unset_options
    klass = build_definition { form_layout { section :a, :x } }
    s = klass.defined_form_layout.first
    assert_nil s.description
    refute s.collapsible?
    refute s.collapsed?
    assert_nil s.columns
    assert_nil s.condition
  end
end

# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::FormLayoutResolutionTest < Minitest::Test
  def definition(&block)
    Class.new(Plutonium::Definition::Base, &block).new
  end

  def test_returns_nil_without_layout
    assert_nil definition {}.resolve_form_sections(%i[a b])
  end

  def test_assigns_fields_and_collects_leftovers_last_by_default
    d = definition do
      form_layout do
        section :identity, :name, :email
      end
    end
    resolved = d.resolve_form_sections(%i[name email notes secret])
    # Without an explicit `ungrouped` macro, leftovers render *after* the
    # declared sections.
    assert_equal %i[identity ungrouped], resolved.map { |r| r.section.key }
    assert_equal %i[name email], resolved.first.fields
    assert_equal %i[notes secret], resolved.last.fields
  end

  def test_ungrouped_macro_controls_position_and_options
    d = definition do
      form_layout do
        section :identity, :name
        ungrouped label: "Other"
      end
    end
    resolved = d.resolve_form_sections(%i[name notes])
    assert_equal %i[identity ungrouped], resolved.map { |r| r.section.key }
    assert_equal "Other", resolved.last.section.label
    assert_equal %i[notes], resolved.last.fields
  end

  def test_preserves_section_field_order
    d = definition { form_layout { section :a, :two, :one } }
    resolved = d.resolve_form_sections(%i[one two])
    assert_equal %i[two one], resolved.find { |r| r.section.key == :a }.fields
  end

  def test_empty_section_kept_when_field_filtered
    d = definition {
      form_layout {
        section :a, :name
        section :b, :name
      }
    }
    resolved = d.resolve_form_sections(%i[name])
    keys = resolved.map { |r| r.section.key }
    assert_includes keys, :b
    assert_empty resolved.find { |r| r.section.key == :b }.fields
    # first-section-wins: :a renders :name
    assert_equal %i[name], resolved.find { |r| r.section.key == :a }.fields
  end

  def test_unknown_field_raises
    d = definition { form_layout { section :a, :nope } }
    error = assert_raises(ArgumentError) { d.resolve_form_sections(%i[name]) }
    assert_match(/unknown field :nope/, error.message)
  end
end

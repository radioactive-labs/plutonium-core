# frozen_string_literal: true

require "test_helper"

# Characterizes the current state of nested inputs on *interactions*.
#
# Two halves, and only one works:
#
#   1. Param handling — `accepts_nested_attributes_for` (the interaction's own
#      lightweight version) defines `<assoc>_attributes=` which builds nested
#      objects from submitted params. This works.
#
#   2. Form rendering — the nested-field renderer resolves its template object
#      and metadata (`:class`, `:macro`, `:limit`, multiplicity) from
#      `resource_class.all_nested_attributes_options`, which only reflects
#      ActiveRecord associations on the acted-on resource. A nested input
#      declared on the interaction is invisible to it, so `blank_object` comes
#      back nil and `nest_one`/`nest_many` have nothing to render. This is the
#      gap: there is no rendering equivalent of resource nested inputs.
#
# These tests pin that split so a future fix has a baseline.
class Plutonium::UI::Form::InteractionNestedInputTest < ActiveSupport::TestCase
  NestedFieldContext =
    Plutonium::UI::Form::Concerns::RendersNestedResourceFields::NestedFieldContext

  # Fields definition for the nested input.
  class GizmoFields < Plutonium::Definition::Base
    input :name
  end

  # An interaction with a nested input that is NOT an association on the
  # acted-on resource — the interaction-only case.
  class NestedGizmoInteraction < Plutonium::Resource::Interaction
    attribute :gizmos
    accepts_nested_attributes_for :gizmos, class_name: "Widget"
    nested_input :gizmos, using: GizmoFields, fields: %i[name]
  end

  def build_interaction
    NestedGizmoInteraction.new(view_context: nil)
  end

  # --- Half 1: param handling works -------------------------------------

  test "accepts_nested_attributes_for builds nested objects from array params" do
    interaction = build_interaction
    interaction.gizmos_attributes = [{name: "A"}, {name: "B"}]

    gizmos = Array(interaction.gizmos)
    assert_equal 2, gizmos.size
    assert_equal %w[A B], gizmos.map(&:name)
    assert(gizmos.all? { |g| g.is_a?(Widget) })
  end

  test "the nested_input DSL is registered on the interaction" do
    assert build_interaction.defined_nested_inputs.key?(:gizmos)
  end

  # --- Half 2: form rendering metadata is missing -----------------------

  test "all_nested_attributes_options on the acted-on resource does not see interaction nested inputs" do
    refute Widget.all_nested_attributes_options.key?(:gizmos)
  end

  test "NestedFieldContext cannot resolve a template object for an interaction nested input" do
    context = NestedFieldContext.new(
      name: :gizmos,
      definition: GizmoFields,
      resource_class: Widget,          # the acted-on resource (no :gizmos nested attrs)
      resource_definition: build_interaction,
      object_class: nil
    )

    # No metadata is available...
    assert_empty context.nested_attribute_options
    # ...so there is no class to instantiate for the blank/template record,
    # which is what nest_one/nest_many need to render the nested UI.
    assert_nil context.blank_object,
      "interaction nested input has no resolvable class -> nested fields cannot render"
  end

  test "passing object_class is the only escape hatch, but multiplicity is still wrong" do
    context = NestedFieldContext.new(
      name: :gizmos,
      definition: GizmoFields,
      resource_class: Widget,
      resource_definition: build_interaction,
      object_class: Widget        # caller must hand-feed the class
    )

    # With an explicit object_class the template object resolves...
    assert_instance_of Widget, context.blank_object
    # ...but with no association metadata the renderer can't know the macro, so
    # it always falls back to the has_many (multiple) path — a has_one nested
    # input on an interaction would render incorrectly.
    assert context.nested_fields_multiple?,
      "no :macro metadata -> always treated as has_many, even for has_one"
  end
end

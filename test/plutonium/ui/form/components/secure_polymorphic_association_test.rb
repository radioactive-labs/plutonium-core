# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::SecurePolymorphicAssociationTest < Minitest::Test
  def test_choices_uses_raw_choices_when_provided
    user_choices = {"Users" => [["Alice", "1"]], "Teams" => [["Dev", "2"]]}
    component = build_component(raw_choices: user_choices)

    mapper = component.send(:choices)

    assert_equal user_choices, mapper.instance_variable_get(:@collection)
  end

  def test_choices_falls_back_to_associated_classes_when_no_raw_choices
    component = build_component(associated_classes: [])

    mapper = component.send(:choices)

    assert_equal({}, mapper.instance_variable_get(:@collection))
  end

  private

  def build_component(raw_choices: nil, associated_classes: [], skip_authorization: true)
    component = Plutonium::UI::Form::Components::SecurePolymorphicAssociation.allocate
    component.instance_variable_set(:@raw_choices, raw_choices)
    component.instance_variable_set(:@skip_authorization, skip_authorization)
    component.instance_variable_set(:@group_method, :last)

    resolved_classes = associated_classes
    component.define_singleton_method(:associated_classes) { resolved_classes }

    component
  end
end

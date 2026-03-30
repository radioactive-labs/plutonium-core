# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::ResourceSelectTest < Minitest::Test
  def test_choices_uses_raw_choices_when_provided
    user_choices = [["Alice", "1"], ["Bob", "2"]]
    component = build_component(raw_choices: user_choices)

    mapper = component.send(:choices)

    assert_equal user_choices, mapper.instance_variable_get(:@collection)
  end

  def test_choices_falls_back_to_association_class_all_when_no_raw_choices
    relation = Object.new
    component = build_component(association_class: stub_class(relation))

    mapper = component.send(:choices)

    assert_equal relation, mapper.instance_variable_get(:@collection)
  end

  def test_choices_returns_empty_when_no_raw_choices_and_no_association_class
    component = build_component

    mapper = component.send(:choices)

    assert_equal [], mapper.instance_variable_get(:@collection)
  end

  private

  def build_component(raw_choices: nil, association_class: nil)
    component = Plutonium::UI::Form::Components::ResourceSelect.allocate
    component.instance_variable_set(:@raw_choices, raw_choices)
    component.instance_variable_set(:@association_class, association_class)
    component
  end

  def stub_class(relation)
    klass = Class.new
    klass.define_singleton_method(:all) { relation }
    klass
  end
end

# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::StructuredInputsTest < Minitest::Test
  def build_interaction(&block)
    Class.new(Plutonium::Resource::Interaction, &block)
  end

  def test_single_declares_attribute_defaulting_to_hash
    klass = build_interaction do
      structured_input(:address) { |f| f.input :street }
    end
    instance = klass.new(view_context: nil)
    assert_includes instance.attribute_names, "address"
    assert_equal({}, instance.address)
  end

  def test_repeat_declares_attribute_defaulting_to_array
    klass = build_interaction do
      structured_input(:contacts, repeat: 3) { |f| f.input :label }
    end
    assert_equal [], klass.new(view_context: nil).contacts
  end

  def test_defaults_are_not_shared_between_instances
    klass = build_interaction do
      structured_input(:contacts, repeat: 3) { |f| f.input :label }
    end
    a = klass.new(view_context: nil)
    a.contacts << {label: "x"}
    b = klass.new(view_context: nil)
    assert_equal [], b.contacts
  end

  def test_nested_input_is_removed_from_interactions
    refute Plutonium::Resource::Interaction.respond_to?(:nested_input)
    refute Plutonium::Resource::Interaction.respond_to?(:accepts_nested_attributes_for)
    refute Plutonium::Resource::Interaction.respond_to?(:defined_nested_inputs)
  end
end

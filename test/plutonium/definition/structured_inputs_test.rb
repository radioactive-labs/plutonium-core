# test/plutonium/definition/structured_inputs_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::StructuredInputsTest < Minitest::Test
  def build_definition(&block)
    Class.new(Plutonium::Definition::Base, &block)
  end

  def test_registers_a_structured_input_with_its_block
    klass = build_definition do
      structured_input :address do |f|
        f.input :street
        f.input :city
      end
    end

    entry = klass.defined_structured_inputs[:address]
    refute_nil entry
    assert_kind_of Proc, entry[:block]
  end

  def test_captures_repeat_and_limit_options
    klass = build_definition do
      structured_input :contacts, repeat: 10 do |f|
        f.input :label
      end
    end

    assert_equal 10, klass.defined_structured_inputs[:contacts][:options][:repeat]
  end

  def test_fields_holder_exposes_declared_inputs
    klass = build_definition do
      structured_input :address do |f|
        f.input :street
        f.input :city
      end
    end

    holder = Plutonium::Definition::StructuredInputs::FieldsDefinition.new
    klass.defined_structured_inputs[:address][:block].call(holder)
    assert_equal %i[street city], holder.defined_inputs.keys
  end

  def test_subclasses_inherit_registry
    parent = build_definition do
      structured_input(:a) { |f| f.input :x }
    end
    child = Class.new(parent)
    assert child.defined_structured_inputs.key?(:a)
  end
end

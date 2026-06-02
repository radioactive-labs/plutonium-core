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

  def test_requires_a_block_or_using_option
    error = assert_raises(ArgumentError) do
      build_definition { structured_input :address }
    end
    assert_match(/needs a block or `using:`/, error.message)
  end

  def test_accepts_using_option_without_a_block
    klass = build_definition do
      structured_input :address, using: Plutonium::Definition::StructuredInputs::FieldsDefinition
    end
    assert_equal Plutonium::Definition::StructuredInputs::FieldsDefinition,
      klass.defined_structured_inputs[:address][:options][:using]
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

  # The form's render path holds a definition INSTANCE; it must be able to read
  # the registry (the existing defined_nested_inputs exposes an instance method).
  def test_instance_exposes_registry
    klass = build_definition do
      structured_input(:a) { |f| f.input :x }
    end
    instance = klass.new
    assert_respond_to instance, :defined_structured_inputs
    assert instance.defined_structured_inputs.key?(:a)
  end
end

# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::JsonTest < Minitest::Test
  Component = Plutonium::UI::Form::Components::Json

  def test_serializes_hash_value_as_pretty_json
    assert_equal JSON.pretty_generate({"k" => "v"}), serialized_for({"k" => "v"})
  end

  def test_serializes_array_value_as_pretty_json
    assert_equal JSON.pretty_generate([1, 2, 3]), serialized_for([1, 2, 3])
  end

  def test_passes_nil_through_as_empty_string
    assert_equal "", serialized_for(nil)
  end

  def test_pretty_formats_parseable_string_input
    assert_equal JSON.pretty_generate({"k" => "v"}), serialized_for('{"k":"v"}')
  end

  def test_preserves_unparseable_string_for_user_to_fix
    assert_equal "{ malformed", serialized_for("{ malformed")
  end

  def test_normalize_input_parses_valid_json_string
    assert_equal({"k" => "v"}, normalize('{"k":"v"}'))
  end

  def test_normalize_input_passes_through_already_parsed_hash
    # JSON-bodied API requests arrive as parsed Hash in params.
    assert_equal({"k" => "v"}, normalize({"k" => "v"}))
  end

  def test_normalize_input_passes_through_already_parsed_array
    assert_equal [1, 2], normalize([1, 2])
  end

  def test_normalize_input_returns_nil_for_blank
    assert_nil normalize(nil)
    assert_nil normalize("")
  end

  def test_normalize_input_passes_invalid_string_through_so_model_can_validate
    # We don't silently swallow garbage — the model's JSON cast or a
    # validation surfaces the error.
    assert_equal "{ broken", normalize("{ broken")
  end

  private

  def serialized_for(value)
    component = Component.allocate
    field_stub = Struct.new(:value).new(value)
    component.define_singleton_method(:field) { field_stub }
    component.send(:serialized_value)
  end

  def normalize(input)
    Component.allocate.send(:normalize_input, input)
  end
end

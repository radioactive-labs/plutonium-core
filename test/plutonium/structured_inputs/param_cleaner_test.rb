# test/plutonium/structured_inputs/param_cleaner_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::StructuredInputs::ParamCleanerTest < Minitest::Test
  Cleaner = Plutonium::StructuredInputs::ParamCleaner

  def test_single_passes_hash_through
    assert_equal({street: "1 A St", city: "Town"},
      Cleaner.call({"street" => "1 A St", "city" => "Town"}, repeat: false))
  end

  def test_single_strips_destroy
    assert_equal({street: "x"}, Cleaner.call({"street" => "x", "_destroy" => "1"}, repeat: false))
  end

  def test_single_blank_returns_empty_hash
    assert_equal({}, Cleaner.call(nil, repeat: false))
  end

  def test_repeater_normalizes_array
    input = [{"label" => "a"}, {"label" => "b"}]
    assert_equal [{label: "a"}, {label: "b"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_normalizes_index_keyed_hash
    input = {"0" => {"label" => "a"}, "1" => {"label" => "b"}}
    assert_equal [{label: "a"}, {label: "b"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_drops_all_blank_rows_and_strips_destroy
    input = [{"label" => "a", "_destroy" => "false"}, {"label" => ""}, {"label" => "c", "_destroy" => "1"}]
    assert_equal [{label: "a"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_blank_returns_empty_array
    assert_equal [], Cleaner.call(nil, repeat: true)
  end
end

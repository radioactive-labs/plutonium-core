# test/plutonium/structured_inputs/param_cleaner_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::StructuredInputs::ParamCleanerTest < Minitest::Test
  Cleaner = Plutonium::StructuredInputs::ParamCleaner

  def test_single_symbolizes_hash
    assert_equal({street: "1 A St", city: "Town"},
      Cleaner.call({"street" => "1 A St", "city" => "Town"}, repeat: false))
  end

  def test_single_blank_returns_empty_hash
    assert_equal({}, Cleaner.call(nil, repeat: false))
  end

  def test_repeater_symbolizes_each_row
    input = [{"label" => "a"}, {"label" => "b"}]
    assert_equal [{label: "a"}, {label: "b"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_drops_all_blank_rows
    input = [{"label" => "a"}, {"label" => ""}, {"label" => "c"}]
    assert_equal [{label: "a"}, {label: "c"}], Cleaner.call(input, repeat: true)
  end

  def test_repeater_blank_returns_empty_array
    assert_equal [], Cleaner.call(nil, repeat: true)
  end
end

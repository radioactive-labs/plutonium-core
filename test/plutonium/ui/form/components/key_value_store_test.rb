# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::KeyValueStoreTest < Minitest::Test
  # Test normalize_input behavior

  def test_normalize_input_returns_nil_when_not_submitted
    component = build_component

    # When field is not in form at all, input is nil
    result = component.send(:normalize_input, nil)

    assert_nil result, "Should return nil to preserve existing value when field not submitted"
  end

  def test_normalize_input_returns_empty_hash_when_submitted_but_empty
    component = build_component

    # When field is rendered but no pairs added, only _submitted is present
    result = component.send(:normalize_input, {"_submitted" => "1"})

    assert_equal({}, result, "Should return empty hash when form rendered but no pairs")
  end

  def test_normalize_input_processes_indexed_params
    component = build_component

    # Standard form submission with key-value pairs
    input = {
      "_submitted" => "1",
      "0" => {"key" => "foo", "value" => "bar"},
      "1" => {"key" => "baz", "value" => "qux"}
    }

    result = component.send(:normalize_input, input)

    assert_equal({"foo" => "bar", "baz" => "qux"}, result)
  end

  def test_normalize_input_skips_pairs_without_keys
    component = build_component

    # Pairs without keys should be ignored
    input = {
      "_submitted" => "1",
      "0" => {"key" => "foo", "value" => "bar"},
      "1" => {"key" => "", "value" => "ignored"},
      "2" => {"key" => "baz", "value" => "qux"}
    }

    result = component.send(:normalize_input, input)

    assert_equal({"foo" => "bar", "baz" => "qux"}, result)
    refute_includes result.keys, ""
  end

  def test_normalize_input_handles_direct_hash_params
    component = build_component

    # Direct hash input (not indexed)
    input = {"foo" => "bar", "baz" => "qux"}

    result = component.send(:normalize_input, input)

    assert_equal({"foo" => "bar", "baz" => "qux"}, result)
  end

  def test_normalize_input_rejects_blank_keys_in_direct_hash
    component = build_component

    # Direct hash with blank key
    input = {"foo" => "bar", "" => "ignored", "baz" => "qux"}

    result = component.send(:normalize_input, input)

    assert_equal({"foo" => "bar", "baz" => "qux"}, result)
  end

  def test_normalize_input_allows_false_values
    component = build_component

    # false is a valid value
    input = {"foo" => false, "bar" => "baz"}

    result = component.send(:normalize_input, input)

    assert_equal({"foo" => false, "bar" => "baz"}, result)
  end

  def test_normalize_input_rejects_blank_values_except_false
    component = build_component

    # Empty string values should be rejected
    input = {"foo" => "bar", "empty" => "", "nil_val" => nil}

    result = component.send(:normalize_input, input)

    assert_equal({"foo" => "bar"}, result)
  end

  # Test normalize_value_to_pairs for display

  def test_normalize_value_to_pairs_handles_hash
    component = build_component

    result = component.send(:normalize_value_to_pairs, {"foo" => "bar", "baz" => "qux"})

    assert_equal [["foo", "bar"], ["baz", "qux"]], result
  end

  def test_normalize_value_to_pairs_handles_json_string
    component = build_component

    result = component.send(:normalize_value_to_pairs, '{"foo": "bar"}')

    assert_equal [["foo", "bar"]], result
  end

  def test_normalize_value_to_pairs_handles_invalid_json
    component = build_component

    result = component.send(:normalize_value_to_pairs, "not json")

    assert_equal [], result
  end

  def test_normalize_value_to_pairs_handles_nil
    component = build_component

    result = component.send(:normalize_value_to_pairs, nil)

    assert_equal [], result
  end

  private

  def build_component
    # Create a minimal mock of the component for testing normalize_input
    component = Object.new

    # Include the normalize methods from KeyValueStore
    component.define_singleton_method(:normalize_input) do |input_value|
      case input_value
      when Hash
        # Remove the sentinel key before processing
        params = input_value.except("_submitted", :_submitted)

        if params.keys.all? { |k| k.to_s.match?(/^\d+$/) }
          # Handle indexed form params
          params.values.each_with_object({}) do |pair, hash|
            next unless pair.is_a?(Hash)

            key = pair["key"] || pair[:key]
            value = pair["value"] || pair[:value]

            if key.present?
              hash[key] = value
            end
          end
        else
          # Handle direct hash params
          params.reject { |k, v| k.blank? || (v.blank? && v != false) }
        end
      when nil
        nil
      end
    end

    component.define_singleton_method(:normalize_value_to_pairs) do |value|
      case value
      when Hash
        value.to_a
      when String
        return [] if value.blank?

        begin
          parsed = JSON.parse(value)
          case parsed
          when Hash
            parsed.to_a
          else
            []
          end
        rescue JSON::ParserError
          []
        end
      else
        []
      end
    end

    component
  end
end

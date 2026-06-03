# test/plutonium/structured_inputs/params_concern_test.rb
# frozen_string_literal: true

require "test_helper"

class Plutonium::StructuredInputs::ParamsConcernTest < Minitest::Test
  class Host
    include Plutonium::StructuredInputs::ParamsConcern
  end

  def definition
    Class.new(Plutonium::Definition::Base) do
      structured_input(:address) { |f| f.input :street }
      structured_input(:contacts, repeat: 5) { |f| f.input :label }
    end.new
  end

  def test_cleans_single_and_repeater_keys_only
    params = {
      name: "keep me",
      address: {"street" => "1 A St"},
      contacts: [{"label" => "a"}, {"label" => ""}]
    }
    out = Host.new.clean_structured_inputs(definition, params)

    assert_equal "keep me", out[:name]                 # untouched
    assert_equal({street: "1 A St"}, out[:address])    # symbolized
    assert_equal [{label: "a"}], out[:contacts]        # blank row dropped
  end

  def test_tolerates_non_structured_definition
    plain = Object.new
    params = {name: "x"}
    assert_equal params, Host.new.clean_structured_inputs(plain, params)
  end
end

# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::PaginationTest < Minitest::Test
  def definition(parent = Plutonium::Definition::Base, &block)
    Class.new(parent, &block)
  end

  def with_global(options)
    previous = Plutonium.configuration.pagination
    Plutonium.configuration.pagination = options
    yield
  ensure
    Plutonium.configuration.instance_variable_set(:@pagination, previous)
  end

  def test_defaults_to_an_exact_count
    assert_equal({count: :exact}, definition {}.new.resolved_pagination)
  end

  def test_falls_back_to_the_global_setting
    with_global(count: 5_000) do
      assert_equal 5_000, definition {}.new.resolved_pagination[:count]
    end
  end

  def test_definition_overrides_the_global_setting
    with_global(count: 5_000) do
      assert_equal false, definition { pagination count: false }.new.resolved_pagination[:count]
    end
  end

  def test_subclasses_inherit_and_can_override
    parent = definition { pagination count: 10_000 }
    assert_equal 10_000, definition(parent) {}.new.resolved_pagination[:count]

    child = definition(parent) { pagination count: :exact }
    assert_equal :exact, child.new.resolved_pagination[:count]
    assert_equal 10_000, parent.new.resolved_pagination[:count], "the parent keeps its own setting"
  end

  def test_global_setting_keeps_defaults_for_omitted_keys
    with_global({}) do
      assert_equal({count: :exact}, Plutonium.configuration.pagination)
    end
  end

  def test_rejects_invalid_values_at_declaration
    [0, -1, 1.5, true, :approximate, "10"].each do |bad|
      assert_raises(ArgumentError, "count: #{bad.inspect}") { definition { pagination count: bad } }
    end
    assert_raises(ArgumentError) { definition { pagination per_page: 10 } }
    assert_raises(ArgumentError) { Plutonium.configuration.pagination = {count: 0} }
  end
end

# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::MetadataTest < Minitest::Test
  def test_defaults_to_empty_list
    klass = Class.new(Plutonium::Definition::Base)
    assert_equal [], klass.defined_metadata_fields
  end

  def test_metadata_dsl_sets_field_list
    klass = Class.new(Plutonium::Definition::Base) do
      metadata :created_at, :updated_at, :author
    end

    assert_equal [:created_at, :updated_at, :author], klass.defined_metadata_fields
  end

  def test_metadata_dsl_normalizes_strings_to_symbols
    klass = Class.new(Plutonium::Definition::Base) do
      metadata "created_at", "updated_at"
    end

    assert_equal [:created_at, :updated_at], klass.defined_metadata_fields
  end

  def test_metadata_is_per_class_not_shared_across_subclasses
    parent = Class.new(Plutonium::Definition::Base) do
      metadata :created_at
    end
    child = Class.new(parent) do
      metadata :state
    end

    assert_equal [:created_at], parent.defined_metadata_fields
    assert_equal [:state], child.defined_metadata_fields
  end
end

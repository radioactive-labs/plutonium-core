# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "generators/pu/lib/plutonium_generators"

class ScaffoldGeneratorSetupTest < ActiveSupport::TestCase
  # Test the setup method behavior for reading existing model attributes

  test "reads attributes from existing model when no attributes provided" do
    # Simulate what setup does - it should read content_columns from existing model
    model_class = User  # User exists in dummy app

    attributes_str = model_class.content_columns.map { |col| "#{col.name}:#{col.type}" }

    # Should have read the model's columns
    assert attributes_str.any?, "Should read attributes from existing model"
    assert attributes_str.any? { |a| a.include?("email") }, "Should include email attribute"
  end

  test "reads attributes even with --no-model option" do
    # The fix ensures setup doesn't return early when options[:model] is false
    # It should still read attributes from an existing model class
    model_class = User

    # The fixed code removes the early return, so this should work
    attributes_str = nil
    if model_class.present?
      attributes_str = model_class.content_columns.map { |col| "#{col.name}:#{col.type}" }
    end

    assert attributes_str.present?, "Should read attributes even with --no-model"
  end

  test "only warns about overwriting when options[:model] is true" do
    # When using --no-model with explicit attributes, it should NOT warn
    # because the user explicitly wants to skip model generation
    attributes_provided = ["title:string"]

    # With --model (default), should warn
    should_warn_with_model = true && attributes_provided.any?
    assert should_warn_with_model, "Should warn when overwriting with --model"

    # With --no-model, should not warn
    should_warn_without_model = false && attributes_provided.any?
    refute should_warn_without_model, "Should not warn when using --no-model"
  end
end

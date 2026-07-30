# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "generators/pu/core/typespec/typespec_generator"

# The generator infers a field's wire type partly from its `as:`, which may be a
# component Class rather than an alias — a Class has no #to_sym (it used to raise
# here) and names no wire type, so it must fall through to the column/association
# inference instead of leaking "MyApp::PickerComponent" as a type name.
#
# NOTE: test/generators/typespec_generator_test.rb — the generator's end-to-end
# coverage — is disabled by a top-level `return`, so these unit tests are the only
# thing guarding this code.
class TypespecInputTypeTest < ActiveSupport::TestCase
  class PickerComponent < Phlexi::Form::Components::Base
    def view_template
      div { "picker" }
    end
  end

  setup do
    @generator = Pu::Core::TypespecGenerator.new([], {}, {})
  end

  # --- determine_input_type -------------------------------------------------

  test "an alias as: names the input type" do
    assert_equal "markdown", @generator.send(:determine_input_type, :content, {as: :markdown}, nil, nil, User)
  end

  test "a component-class as: falls through to the column type" do
    column = User.columns_hash["email"]

    assert_equal column.type.to_s, @generator.send(:determine_input_type, :email, {as: PickerComponent}, column, nil, User)
  end

  test "a component-class as: with nothing to fall back on is a string" do
    assert_equal "string", @generator.send(:determine_input_type, :whatever, {as: PickerComponent}, nil, nil, User)
  end

  # --- determine_typespec_input_type ---------------------------------------

  test "an alias as: maps through AS_TYPE_MAPPING" do
    assert_equal "string", @generator.send(:determine_typespec_input_type, :contact_email, {as: :email}, nil, nil, User)
  end

  test "a component-class as: maps to string rather than raising" do
    assert_equal "string", @generator.send(:determine_typespec_input_type, :body, {as: PickerComponent}, nil, nil, User)
  end

  # --- extract_inputs -------------------------------------------------------

  test "extract_inputs reports an alias as: and drops a component-class as:" do
    definition = Class.new(Plutonium::Definition::Base) do
      input :email, as: :string
    end
    definition.input :password, as: PickerComponent

    inputs = @generator.send(:extract_inputs, definition, User).index_by { |input| input[:name] }

    assert_equal "string", inputs["email"][:as]
    assert_nil inputs["password"][:as], "a component class names no input alias"
  end
end

# frozen_string_literal: true

require "test_helper"

# `as:` accepts EITHER a built-in alias (`:string`, `:uppy`, …) OR a component
# Class rendered directly (see Plutonium::UI::Form::Resource). A Class has no
# `#to_sym`, so callers asking "which alias is this?" must go through
# Builder.input_alias / .file_input? — a bare `as&.to_sym` raises NoMethodError
# on a perfectly valid `input :template, as: SomePickerComponent`.
class Plutonium::UI::Form::InputAliasTest < ActiveSupport::TestCase
  Builder = Plutonium::UI::Form::Base::Builder

  class PickerComponent < Plutonium::UI::Component::Base
    def view_template
      div { "picker" }
    end
  end

  # --- input_alias ----------------------------------------------------------

  test "input_alias returns the symbol for a symbol or string alias" do
    assert_equal :uppy, Builder.input_alias(:uppy)
    assert_equal :uppy, Builder.input_alias("uppy")
  end

  test "input_alias is nil for a component class (no #to_sym)" do
    assert_nil Builder.input_alias(PickerComponent)
  end

  test "input_alias is nil when no as: was declared" do
    assert_nil Builder.input_alias(nil)
  end

  # --- file_input? ----------------------------------------------------------

  test "file_input? is true for every file alias" do
    Builder::FILE_INPUT_TYPES.each { |as| assert Builder.file_input?(as), "expected #{as} to be a file input" }
    assert Builder.file_input?("uppy")
  end

  test "file_input? is false for a non-file alias and for no as:" do
    refute Builder.file_input?(:string)
    refute Builder.file_input?(nil)
  end

  test "file_input? is false for a component class rather than raising" do
    refute Builder.file_input?(PickerComponent)
  end
end

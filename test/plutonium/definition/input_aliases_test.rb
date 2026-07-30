# frozen_string_literal: true

require "test_helper"

# `as:` accepts EITHER an input alias (`:string`, `:uppy`, …) OR a component
# Class rendered directly (see Plutonium::UI::Component::ResolvesTags). A Class
# has no `#to_sym`, so callers asking "which alias is this?" must go through
# InputAliases.resolve / .file_input? — a bare `as&.to_sym` raises NoMethodError
# on a perfectly valid `input :template, as: SomePickerComponent`.
class Plutonium::Definition::InputAliasesTest < ActiveSupport::TestCase
  InputAliases = Plutonium::Definition::InputAliases

  class PickerComponent < Plutonium::UI::Component::Base
    def view_template
      div { "picker" }
    end
  end

  # --- resolve --------------------------------------------------------------

  test "resolve returns the symbol for a symbol or string alias" do
    assert_equal :uppy, InputAliases.resolve(:uppy)
    assert_equal :uppy, InputAliases.resolve("uppy")
  end

  test "resolve is nil for a component class (no #to_sym)" do
    assert_nil InputAliases.resolve(PickerComponent)
  end

  test "resolve is nil when no as: was declared" do
    assert_nil InputAliases.resolve(nil)
  end

  # --- file_input? ----------------------------------------------------------

  test "file_input? is true for every file alias" do
    InputAliases::FILE_INPUT_TYPES.each { |as| assert InputAliases.file_input?(as), "expected #{as} to be a file input" }
    assert InputAliases.file_input?("uppy")
  end

  test "file_input? is false for a non-file alias and for no as:" do
    refute InputAliases.file_input?(:string)
    refute InputAliases.file_input?(nil)
  end

  test "file_input? is false for a component class rather than raising" do
    refute InputAliases.file_input?(PickerComponent)
  end

  # The form builder aliases each file type's tag to Uppy off this same list, so
  # an entry added here can't silently become an unknown tag.
  test "every file alias has a form tag" do
    field = Plutonium::UI::Form::Resource.new(
      User.new,
      resource_fields: [:email],
      resource_definition: Plutonium::Definition::Base.new,
      singular_resource: false
    ).field(:email)

    InputAliases::FILE_INPUT_TYPES.each { |as| assert_respond_to field, :"#{as}_tag" }
  end
end

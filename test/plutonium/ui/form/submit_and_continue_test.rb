# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::SubmitAndContinueTest < ActiveSupport::TestCase
  class TestDefinition < Plutonium::Definition::Base
  end

  class SingularDefinition < Plutonium::Definition::Base
    submit_and_continue false
  end

  class AlwaysShowDefinition < Plutonium::Definition::Base
    submit_and_continue true
  end

  setup do
    @user = User.new(email: "test@example.com")
  end

  test "show_submit_and_continue? returns true for plural resources by default" do
    form = build_form(@user, definition: TestDefinition.new, singular: false)

    assert form.send(:show_submit_and_continue?)
  end

  test "show_submit_and_continue? returns false for singular resources by default" do
    form = build_form(@user, definition: TestDefinition.new, singular: true)

    refute form.send(:show_submit_and_continue?)
  end

  test "show_submit_and_continue? respects explicit false config" do
    form = build_form(@user, definition: SingularDefinition.new, singular: false)

    refute form.send(:show_submit_and_continue?)
  end

  test "show_submit_and_continue? respects explicit true config even for singular" do
    form = build_form(@user, definition: AlwaysShowDefinition.new, singular: true)

    assert form.send(:show_submit_and_continue?)
  end

  test "show_submit_and_continue? returns false for non-ActiveRecord objects" do
    plain_object = Object.new
    form = build_form(plain_object, definition: TestDefinition.new, singular: false)

    refute form.send(:show_submit_and_continue?)
  end

  test "submit_and_continue config is inherited by subclasses" do
    parent = Class.new(Plutonium::Definition::Base) do
      submit_and_continue false
    end
    child = Class.new(parent)

    assert_equal false, parent.submit_and_continue
    assert_equal false, child.submit_and_continue
  end

  test "submit_and_continue config can be overridden by subclasses" do
    parent = Class.new(Plutonium::Definition::Base) do
      submit_and_continue false
    end
    child = Class.new(parent) do
      submit_and_continue true
    end

    assert_equal false, parent.submit_and_continue
    assert_equal true, child.submit_and_continue
  end

  private

  def build_form(object, definition:, singular:)
    Plutonium::UI::Form::Resource.new(
      object,
      resource_fields: [:email],
      resource_definition: definition,
      singular_resource: singular
    )
  end
end

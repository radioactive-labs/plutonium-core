# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::HiddenInputTest < ActiveSupport::TestCase
  # The Builder treats `as: :hidden` as the canonical signal and short-circuits
  # `wrapped` to a label-less HiddenWrapper. Resource forms keep `:as` in the
  # options they pass to `form.field` so the Builder can see it.

  setup do
    @form = Plutonium::UI::Form::Resource.new(
      User.new(email: "test@example.com"),
      resource_fields: [:email],
      resource_definition: Plutonium::Definition::Base.new,
      singular_resource: false
    )
  end

  test "hidden? is true when as: :hidden" do
    assert @form.field(:email, as: :hidden).hidden?
  end

  test "hidden? is true when as: \"hidden\"" do
    assert @form.field(:email, as: "hidden").hidden?
  end

  test "hidden? is false for visible :as values" do
    refute @form.field(:email, as: :string).hidden?
    refute @form.field(:email, as: :select).hidden?
    refute @form.field(:email).hidden?
  end

  test ":as is consumed by the Builder, not stored in Phlexi's @options" do
    field = @form.field(:email, as: :hidden)
    refute field.options.key?(:as), "expected :as to be peeled off; got options=#{field.options.inspect}"
  end

  test "wrapped returns the HiddenWrapper for hidden fields" do
    component = @form.field(:email, as: :hidden).wrapped

    assert_instance_of Plutonium::UI::Form::Components::HiddenWrapper, component
  end

  test "wrapped returns the regular Phlexi Wrapper for visible fields" do
    component = @form.field(:email, as: :string).wrapped

    assert_instance_of Phlexi::Form::Components::Wrapper, component
  end

  # Interaction forms inherit from Resource and therefore use the same Builder.
  # Explicit test guards against a future override that breaks the contract.
  test "Interaction form's Builder also treats as: :hidden as hidden" do
    interaction_class = Class.new(Plutonium::Resource::Interaction) do
      attribute :token, :string
    end

    form = Plutonium::UI::Form::Interaction.new(interaction_class.new(view_context: nil))
    field = form.field(:token, as: :hidden)

    assert field.hidden?
    assert_instance_of Plutonium::UI::Form::Components::HiddenWrapper, field.wrapped
  end
end

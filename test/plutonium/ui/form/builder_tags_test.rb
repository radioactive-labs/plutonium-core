# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::BuilderTagsTest < ActiveSupport::TestCase
  def form_field(record, name)
    Plutonium::UI::Form::Resource.new(
      record,
      resource_fields: [name],
      resource_definition: Plutonium::Definition::Base.new,
      singular_resource: false
    ).field(name)
  end

  # phlexi-form infers json/jsonb as a plain :text textarea, which renders
  # `Hash#to_s` and never parses the submission back into a Hash.
  test "an inferred json column renders the json input" do
    field = form_field(KitchenSink.new(config: {"theme" => "dark"}), :config)

    assert_instance_of Plutonium::UI::Form::Components::Json, field.component_for(nil)
  end

  # secure_polymorphic_association_tag themes off :polymorphic_association; the
  # keys were spelled `polymorpic_*`, so the select got no classes at all.
  test "the polymorphic association select resolves the association theme" do
    theme = Plutonium::UI::Form::Theme.instance

    assert_equal theme.resolve_theme(:association), theme.resolve_theme(:polymorphic_association)
    assert_equal theme.resolve_theme(:invalid_association), theme.resolve_theme(:invalid_polymorphic_association)
  end

  # phlexi aliases has_and_belongs_to_many_tag to ITS has_many_tag at definition
  # time, so re-aliasing has_many_tag alone leaves habtm on the unscoped select.
  test "habtm renders the policy-scoped association input" do
    builder = Plutonium::UI::Form::Base::Builder

    assert_equal builder.instance_method(:secure_association_tag),
      builder.instance_method(:has_and_belongs_to_many_tag)
  end
end

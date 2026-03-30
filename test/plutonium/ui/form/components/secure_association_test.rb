# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::SecureAssociationTest < Minitest::Test
  def test_add_url_returns_nil_when_association_class_not_registered
    component = build_component(
      registered_resources: [],
      skip_authorization: true
    )

    assert_nil component.send(:add_url)
  end

  def test_add_url_generates_url_when_association_class_is_registered
    component = build_component(
      registered_resources: [DummyUser],
      skip_authorization: true,
      resource_url: "/users/new"
    )

    url = component.send(:add_url)

    assert_includes url, "/users/new"
    assert_includes url, "return_to="
  end

  def test_add_url_returns_nil_when_not_authorized
    component = build_component(
      registered_resources: [DummyUser],
      skip_authorization: false,
      allowed: false
    )

    assert_nil component.send(:add_url)
  end

  def test_add_url_uses_custom_add_action_regardless_of_registration
    component = build_component(
      registered_resources: [],
      skip_authorization: true,
      add_action: "/custom/create"
    )

    url = component.send(:add_url)

    assert_includes url, "/custom/create"
    assert_includes url, "return_to="
  end

  def test_choices_uses_raw_choices_when_provided
    user_choices = [["Alice", "1"], ["Bob", "2"]]
    component = build_component(
      skip_authorization: true,
      raw_choices: user_choices
    )

    mapper = component.send(:choices)

    assert_equal user_choices, mapper.instance_variable_get(:@collection)
  end

  def test_choices_falls_back_to_association_scope_when_no_raw_choices
    relation = Object.new
    component = build_component(
      skip_authorization: true,
      association_scope: relation
    )

    mapper = component.send(:choices)

    assert_equal relation, mapper.instance_variable_get(:@collection)
  end

  private

  def build_component(registered_resources: [], skip_authorization: false, allowed: true, resource_url: nil, add_action: nil, raw_choices: nil, association_scope: nil)
    component = Plutonium::UI::Form::Components::SecureAssociation.allocate

    # Set instance variables that would normally be set by build_attributes
    component.instance_variable_set(:@skip_authorization, skip_authorization)
    component.instance_variable_set(:@add_action, add_action)
    component.instance_variable_set(:@raw_choices, raw_choices)

    # Stub the dependencies
    reflection = Struct.new(:klass, :macro, :name).new(DummyUser, :belongs_to, :user)
    field_stub = Struct.new(:association_reflection).new(reflection)
    request_stub = Struct.new(:original_url).new("http://localhost:3000/teams/new")

    component.define_singleton_method(:field) { field_stub }
    component.define_singleton_method(:registered_resources) { registered_resources }
    component.define_singleton_method(:request) { request_stub }

    if resource_url
      component.define_singleton_method(:resource_url_for) { |*_args, **_kwargs| resource_url }
    end

    if association_scope
      component.define_singleton_method(:choices_from_association) { |_klass| association_scope }
    end

    component.define_singleton_method(:allowed_to?) { |*_args, **_kwargs| allowed }

    component
  end

  class DummyUser; end
end

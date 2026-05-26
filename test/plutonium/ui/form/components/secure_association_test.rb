# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::SecureAssociationTest < Minitest::Test
  def test_add_url_returns_nil_when_association_class_not_registered
    component = build_component(
      registered_resources: [],
      skip_authorization: true
    )

    assert_nil component.send(:add_url_and_frame)
  end

  def test_add_url_generates_url_when_association_class_is_registered
    component = build_component(
      registered_resources: [DummyUser],
      skip_authorization: true,
      resource_url: "/users/new"
    )

    url, frame = component.send(:add_url_and_frame)

    assert_includes url, "/users/new"
    assert_includes url, "return_to="
    assert_equal "remote_modal", frame
  end

  def test_add_url_returns_nil_when_not_authorized
    component = build_component(
      registered_resources: [DummyUser],
      skip_authorization: false,
      allowed: false
    )

    assert_nil component.send(:add_url_and_frame)
  end

  def test_add_url_uses_custom_add_action_regardless_of_registration
    component = build_component(
      registered_resources: [],
      skip_authorization: true,
      add_action: "/custom/create"
    )

    url, frame = component.send(:add_url_and_frame)

    assert_includes url, "/custom/create"
    assert_includes url, "return_to="
    assert_nil frame
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

  def test_normalize_simple_input_accepts_sgid_in_relation_even_when_outside_rendered_choices
    in_scope = User.create!(email: "in-scope-#{SecureRandom.hex(4)}@example.com", password: "password123")
    # `choices` is capped at choice_limit; this validates against the full
    # scoped relation, which is the typeahead-correct behavior.
    relation = User.where(id: in_scope.id)
    component = build_normalize_component(klass: User, relation: relation)

    sgid_str = in_scope.to_signed_global_id.to_s
    result = component.send(:normalize_simple_input, sgid_str)
    assert_equal SignedGlobalID.parse(sgid_str), result
  end

  def test_normalize_simple_input_rejects_sgid_not_in_relation
    in_scope = User.create!(email: "in-#{SecureRandom.hex(4)}@example.com", password: "password123")
    out_of_scope = User.create!(email: "out-#{SecureRandom.hex(4)}@example.com", password: "password123")
    relation = User.where(id: in_scope.id)
    component = build_normalize_component(klass: User, relation: relation)

    assert_nil component.send(:normalize_simple_input, out_of_scope.to_signed_global_id.to_s)
  end

  def test_normalize_simple_input_rejects_sgid_for_wrong_class
    org = Organization.create!(name: "org-#{SecureRandom.hex(4)}")
    component = build_normalize_component(klass: User, relation: User.all)

    assert_nil component.send(:normalize_simple_input, org.to_signed_global_id.to_s)
  end

  def test_normalize_simple_input_rejects_non_sgid_input
    component = build_normalize_component(klass: User, relation: User.all)

    assert_nil component.send(:normalize_simple_input, "not-an-sgid")
    assert_nil component.send(:normalize_simple_input, "")
    assert_nil component.send(:normalize_simple_input, nil)
  end

  def test_normalize_simple_input_validates_against_rendered_list_when_raw_choices_provided
    permitted = User.create!(email: "perm-#{SecureRandom.hex(4)}@example.com", password: "password123")
    rejected = User.create!(email: "rej-#{SecureRandom.hex(4)}@example.com", password: "password123")
    permitted_sgid = permitted.to_signed_global_id.to_s

    component = build_normalize_component(klass: User, relation: nil, raw_choices: [permitted_sgid])
    component.define_singleton_method(:choices) { Struct.new(:values).new([permitted_sgid]) }

    assert_equal SignedGlobalID.parse(permitted_sgid), component.send(:normalize_simple_input, permitted_sgid)
    assert_nil component.send(:normalize_simple_input, rejected.to_signed_global_id.to_s)
  end

  private

  # Lightweight build for normalize_simple_input tests — only what that
  # method touches (reflection.klass, choices_from_association, raw_choices).
  def build_normalize_component(klass:, relation:, raw_choices: nil)
    component = Plutonium::UI::Form::Components::SecureAssociation.allocate
    component.instance_variable_set(:@skip_authorization, true)
    component.instance_variable_set(:@raw_choices, raw_choices)

    reflection = Struct.new(:klass, :macro, :name).new(klass, :belongs_to, :user)
    field_stub = Struct.new(:association_reflection).new(reflection)
    component.define_singleton_method(:field) { field_stub }
    component.define_singleton_method(:choices_from_association) { |_| relation } if relation
    component
  end

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

    action = Struct.new(:route_options, :name) do
      def permitted_by?(policy)
        policy.allowed_to?(:"#{name}?")
      end

      def turbo_frame(_definition) = "remote_modal"
    end.new(:new_route, :new)
    definition = Struct.new(:defined_actions, :modal_mode).new({new: action}, :slideover)
    component.define_singleton_method(:resource_definition) { |_klass| definition }
    component.define_singleton_method(:route_options_to_url) { |_ro, _subject| resource_url || "/users/new" }

    if association_scope
      component.define_singleton_method(:choices_from_association) { |_klass| association_scope }
    end

    component.define_singleton_method(:allowed_to?) { |*_args, **_kwargs| allowed }
    component.define_singleton_method(:in_modal?) { false }
    policy_stub = Object.new
    policy_stub.define_singleton_method(:allowed_to?) { |*_args| allowed }
    component.define_singleton_method(:policy_for) { |**_kwargs| policy_stub }

    component
  end

  class DummyUser; end
end

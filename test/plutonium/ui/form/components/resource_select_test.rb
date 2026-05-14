# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::ResourceSelectTest < Minitest::Test
  def test_choices_uses_raw_choices_when_provided
    user_choices = [["Alice", "1"], ["Bob", "2"]]
    component = build_component(raw_choices: user_choices)

    mapper = component.send(:choices)

    assert_equal user_choices, mapper.instance_variable_get(:@collection)
  end

  def test_choices_falls_back_to_association_class_all_when_no_raw_choices
    relation = Object.new
    component = build_component(association_class: stub_class(relation))

    mapper = component.send(:choices)

    assert_equal relation, mapper.instance_variable_get(:@collection)
  end

  def test_choices_returns_empty_when_no_raw_choices_and_no_association_class
    component = build_component

    mapper = component.send(:choices)

    assert_equal [], mapper.instance_variable_get(:@collection)
  end

  def test_normalize_simple_input_accepts_sgid_in_unbounded_relation
    in_scope = User.create!(email: "rs-in-#{SecureRandom.hex(4)}@example.com", password: "password123")
    component = build_component(association_class: User)
    sgid = in_scope.to_signed_global_id.to_s

    # `choices` is capped at choice_limit but normalize_simple_input now
    # consults the unbounded User.all relation.
    assert_equal sgid, component.send(:normalize_simple_input, sgid)
  end

  def test_normalize_simple_input_rejects_sgid_for_wrong_class
    org = Organization.create!(name: "rs-org-#{SecureRandom.hex(4)}")
    component = build_component(association_class: User)

    assert_nil component.send(:normalize_simple_input, org.to_signed_global_id.to_s)
  end

  def test_normalize_simple_input_returns_nil_for_blank_or_garbage
    component = build_component(association_class: User)

    assert_nil component.send(:normalize_simple_input, nil)
    assert_nil component.send(:normalize_simple_input, "")
    assert_nil component.send(:normalize_simple_input, "garbage")
  end

  def test_normalize_simple_input_falls_back_to_choices_when_raw_choices_provided
    permitted_user = User.create!(email: "rs-perm-#{SecureRandom.hex(4)}@example.com", password: "password123")
    rejected_user = User.create!(email: "rs-rej-#{SecureRandom.hex(4)}@example.com", password: "password123")
    permitted_sgid = permitted_user.to_signed_global_id.to_s

    component = build_component(raw_choices: [permitted_sgid], association_class: User)

    assert_equal permitted_sgid, component.send(:normalize_simple_input, permitted_sgid)
    assert_nil component.send(:normalize_simple_input, rejected_user.to_signed_global_id.to_s)
  end

  private

  def build_component(raw_choices: nil, association_class: nil)
    component = Plutonium::UI::Form::Components::ResourceSelect.allocate
    component.instance_variable_set(:@raw_choices, raw_choices)
    component.instance_variable_set(:@association_class, association_class)
    # Skip the authorized_resource_scope path — it calls view_context,
    # which is unavailable outside a render cycle.
    component.instance_variable_set(:@skip_authorization, true)
    component.instance_variable_set(:@choice_limit, nil)
    component
  end

  def stub_class(relation)
    klass = Class.new
    klass.define_singleton_method(:all) { relation }
    klass
  end
end

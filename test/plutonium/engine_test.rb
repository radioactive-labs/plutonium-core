# frozen_string_literal: true

require "test_helper"

class Plutonium::EngineTest < Minitest::Test
  # Test that scoped_entity_param_key is always suffixed to avoid collision
  # with resource_param_key (which uses model_name.param_key).
  #
  # Without the suffix, when Entity is registered as a singular resource,
  # the path param `:entity` clobbers the form param `entity[name]=...`
  # because Rails merges path params into `params`, making `params[:entity]`
  # a String (path segment) instead of a Hash (form data).

  def test_scoped_entity_param_key_is_suffixed_by_default
    engine_mod = build_engine_module
    engine_mod.scope_to_entity(Organization, strategy: :path)

    assert_equal :organization_scope, engine_mod.scoped_entity_param_key,
      "scoped_entity_param_key should be suffixed with _scope to avoid collision with resource param keys"
  end

  def test_scoped_entity_param_key_respects_custom_param_key
    engine_mod = build_engine_module
    engine_mod.scope_to_entity(Organization, strategy: :path, param_key: :org)

    assert_equal :org, engine_mod.scoped_entity_param_key,
      "Custom param_key should be used as-is (user is responsible for avoiding collisions)"
  end

  def test_scoped_entity_param_key_does_not_collide_with_resource_param_key
    # This is the exact scenario from the bug: Entity model registered as
    # both the scoped entity AND a singular resource.
    engine_mod = build_engine_module
    engine_mod.scope_to_entity(Organization, strategy: :path)

    resource_param_key = Organization.model_name.param_key.to_sym

    refute_equal resource_param_key, engine_mod.scoped_entity_param_key,
      "scoped_entity_param_key (:#{engine_mod.scoped_entity_param_key}) must not equal " \
      "resource_param_key (:#{resource_param_key}) to prevent path param collision"
  end

  def test_existing_org_portal_has_suffixed_param_key
    # Verify the real OrgPortal engine gets the suffix
    assert_equal :organization_scope, OrgPortal::Engine.scoped_entity_param_key
  end

  # scoped_entity_route_key is unaffected by the _scope suffix

  def test_scoped_entity_route_key_is_not_suffixed
    engine_mod = build_engine_module
    engine_mod.scope_to_entity(Organization, strategy: :path)

    assert_equal :organization, engine_mod.scoped_entity_route_key,
      "scoped_entity_route_key should remain unsuffixed (only param_key gets _scope)"
  end

  def test_scoped_entity_route_key_respects_custom_route_key
    engine_mod = build_engine_module
    engine_mod.scope_to_entity(Organization, strategy: :path, route_key: :org)

    assert_equal :org, engine_mod.scoped_entity_route_key
  end

  # Non-path strategies also get the suffix (harmless — param_key is only
  # used in path params for :path strategy, but consistency avoids surprises)

  def test_scoped_entity_param_key_is_suffixed_for_non_path_strategy
    engine_mod = build_engine_module
    engine_mod.scope_to_entity(Organization, strategy: :current_tenant)

    assert_equal :organization_scope, engine_mod.scoped_entity_param_key
  end

  private

  def build_engine_module
    Module.new do
      extend Plutonium::Engine::ClassMethods
    end
  end
end

# frozen_string_literal: true

require "test_helper"

# Unit tests for Plutonium::Kanban::Broadcaster.
#
# Covers:
#   * stream_name scoping — different tenants / nil yield different names
#   * stream_name determinism — same inputs always give the same name
#   * broadcast delegates to ActionCable on the correct stream with the right content
class Plutonium::Kanban::BroadcasterTest < Minitest::Test
  include ActionCable::TestHelper

  # A minimal stub for a scoped entity (has to_gid_param like a GlobalID-backed record).
  def make_entity(id:, type: "Org")
    gid = "gid://dummy/#{type}/#{id}"
    Struct.new(:to_gid_param).new(gid)
  end

  # Converts a Broadcaster.stream_name array to the string ActionCable uses for its channel.
  # turbo-rails joins each string segment with ":" using stream_name_from.
  def cable_stream_name(resource_class:, scoped_entity:)
    Plutonium::Kanban::Broadcaster.stream_name(resource_class:, scoped_entity:).join(":")
  end

  # ---------------------------------------------------------------------------
  # stream_name: structure
  # ---------------------------------------------------------------------------

  def test_stream_name_returns_three_element_array
    name = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
    assert_equal 3, name.size
  end

  def test_stream_name_starts_with_kanban
    name = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
    assert_equal "kanban", name.first
  end

  def test_stream_name_ends_with_resource_class_name
    name = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
    assert_equal "Task", name.last
  end

  # ---------------------------------------------------------------------------
  # stream_name: nil scoped_entity → "global" segment
  # ---------------------------------------------------------------------------

  def test_stream_name_uses_global_when_no_scoped_entity
    name = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
    assert_equal "global", name[1]
  end

  # ---------------------------------------------------------------------------
  # stream_name: scoped_entity present → uses GID param
  # ---------------------------------------------------------------------------

  def test_stream_name_uses_entity_gid_param_when_present
    entity = make_entity(id: 42)
    name = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: entity)
    assert_equal entity.to_gid_param, name[1]
  end

  def test_stream_name_does_not_contain_global_when_entity_present
    entity = make_entity(id: 1)
    name = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: entity)
    refute_includes name, "global"
  end

  # ---------------------------------------------------------------------------
  # stream_name: tenant isolation — different entities ≠ same stream
  # ---------------------------------------------------------------------------

  def test_stream_names_differ_for_different_entities
    entity1 = make_entity(id: 1)
    entity2 = make_entity(id: 2)
    name1 = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: entity1)
    name2 = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: entity2)
    refute_equal name1, name2,
      "different scoped entities must produce different stream names (cross-tenant isolation)"
  end

  def test_stream_name_entity_vs_nil_differ
    entity = make_entity(id: 99)
    name_with_entity = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: entity)
    name_without_entity = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
    refute_equal name_with_entity, name_without_entity,
      "a scoped entity and nil must not share a stream name"
  end

  # ---------------------------------------------------------------------------
  # stream_name: determinism — same inputs → same name
  # ---------------------------------------------------------------------------

  def test_same_inputs_yield_same_name_for_nil_entity
    name1 = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
    name2 = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
    assert_equal name1, name2
  end

  def test_same_inputs_yield_same_name_for_entity
    entity = make_entity(id: 7)
    name1 = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: entity)
    name2 = Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: entity)
    assert_equal name1, name2
  end

  # ---------------------------------------------------------------------------
  # broadcast: sends turbo-stream content on the correct ActionCable stream
  #
  # Use non-block form of assert_broadcasts / assert_broadcast_on so we don't
  # depend on ActiveSupport::Testing::Assertions (_assert_nothing_raised_or_warn
  # is only available in ActiveSupport::TestCase, not Minitest::Test).
  # Each test starts with a fresh adapter (ActionCable::TestHelper#before_setup).
  # ---------------------------------------------------------------------------

  def test_broadcast_sends_to_global_stream_when_no_scoped_entity
    stream = cable_stream_name(resource_class: Task, scoped_entity: nil)
    content = "<turbo-stream action=\"update\" target=\"kanban-col-todo\"></turbo-stream>"

    Plutonium::Kanban::Broadcaster.broadcast(resource_class: Task, scoped_entity: nil, content:)

    assert_broadcasts stream, 1
  end

  def test_broadcast_sends_to_entity_scoped_stream
    entity = make_entity(id: 5)
    stream = cable_stream_name(resource_class: Task, scoped_entity: entity)

    Plutonium::Kanban::Broadcaster.broadcast(resource_class: Task, scoped_entity: entity, content: "html")

    assert_broadcasts stream, 1
  end

  def test_broadcast_does_not_send_to_other_tenant_stream
    entity1 = make_entity(id: 1)
    entity2 = make_entity(id: 2)
    stream_for_entity2 = cable_stream_name(resource_class: Task, scoped_entity: entity2)

    # Broadcast only to entity1's stream — entity2 must see zero messages.
    Plutonium::Kanban::Broadcaster.broadcast(resource_class: Task, scoped_entity: entity1, content: "html")

    assert_broadcasts stream_for_entity2, 0
  end

  def test_broadcast_content_is_transmitted_verbatim
    stream = cable_stream_name(resource_class: Task, scoped_entity: nil)
    content = "<turbo-stream action=\"update\" target=\"kanban-col-todo\">BODY</turbo-stream>"

    Plutonium::Kanban::Broadcaster.broadcast(resource_class: Task, scoped_entity: nil, content:)

    # assert_broadcast_on without block checks accumulated broadcasts.
    assert_broadcast_on stream, content
  end
end

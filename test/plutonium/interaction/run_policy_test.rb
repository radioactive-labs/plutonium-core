# frozen_string_literal: true

require "test_helper"

# The run's own authorization surface.
#
# Two questions, both of which fail OPEN if they are wrong: which runs a user
# may see, and what they may do to one.
class Plutonium::Interaction::RunPolicyTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    # No transactional rollback in this suite, and the runs table is not in
    # IntegrationTestHelper#cleanup_test_data, so clear it explicitly.
    Plutonium::Interaction::Run.delete_all

    @org = create_organization!
    @other = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)

    @mine = TestPostRun.create!(initiator: @user, scoped_entity: @org)
    @theirs = TestPostRun.create!(initiator: @user, scoped_entity: @other)
    @unscoped = TestPostRun.create!(initiator: @user)
  end

  teardown { Plutonium::Interaction::Run.delete_all }

  def policy_for(entity_scope:)
    Plutonium::Interaction::RunPolicy.new(Plutonium::Interaction::Run, user: @user, entity_scope: entity_scope)
  end

  def scope_for(entity_scope:)
    policy_for(entity_scope: entity_scope)
      .apply_scope(Plutonium::Interaction::Run.all, type: :active_record_relation)
  end

  test "a run is visible only inside its own entity scope" do
    scope = scope_for(entity_scope: @org)

    assert_includes scope, @mine
    refute_includes scope, @theirs, "a run from another tenant must never be listed"
  end

  # The tenant filter has to come off the run's OWN recorded scope, not from an
  # association graph: nil scoped_entity means "dispatched outside any tenant",
  # and a tenant-scoped portal is exactly where that must not show up.
  test "a run with no tenant is not visible from inside a tenant" do
    refute_includes scope_for(entity_scope: @org), @unscoped
  end

  test "an unscoped portal sees every run" do
    scope = scope_for(entity_scope: nil)

    assert_includes scope, @mine
    assert_includes scope, @theirs
    assert_includes scope, @unscoped
  end

  # A run is the record of something that already happened. There is no form to
  # submit, and editing one would rewrite the audit trail.
  test "runs are read-only" do
    policy = policy_for(entity_scope: @org)

    assert policy.index?
    assert policy.show?
    refute policy.create?
    refute policy.new?
    refute policy.update?
    refute policy.edit?
    refute policy.destroy?
  end

  # options is arbitrary JSON copied from the dispatching interaction's inputs.
  # Who could SUBMIT them was governed by that interaction's own policy; who can
  # READ this run is a different, wider set (everyone in the tenant). Leaving it
  # out of the readable attributes is what keeps the two apart.
  test "the dispatching interaction's options are not readable" do
    readable = policy_for(entity_scope: @org).permitted_attributes_for_read

    refute_includes readable, :options
    refute_includes readable, :target_ids
    assert_includes readable, :outcome
  end

  # target_label humanizes the raw class name (see Run#target_label) — the
  # column itself is not what the show page/table should render.
  test "target_label is readable in place of the raw target_type column" do
    readable = policy_for(entity_scope: @org).permitted_attributes_for_read

    assert_includes readable, :target_label
    refute_includes readable, :target_type
  end

  # The raw column reads "completed" for a run that failed some of its targets.
  # Only #outcome distinguishes the two, so only #outcome is readable.
  test "the raw state column is not readable on its own" do
    refute_includes policy_for(entity_scope: @org).permitted_attributes_for_read, :state
  end
end

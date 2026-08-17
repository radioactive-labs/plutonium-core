# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::Runs::ContextTest < ActiveSupport::TestCase
  include DataHelpers

  Context = Plutonium::Interaction::Runs::Context

  # This suite has NO transactional rollback — test_helper.rb never loads
  # rails/test_help — so rows persist across tests. Every assertion below is
  # pinned to ids this test created, which is what makes that survivable; the
  # runs table is still cleared because other suites leave rows in it.
  setup do
    Plutonium::Interaction::Run.delete_all

    @user = create_user!
    @org = create_organization!
    @other_org = create_organization!
    @post = create_post!(user: @user, organization: @org, title: "In scope")
    @other_post = create_post!(user: @user, organization: @other_org, title: "Other tenant")
  end

  teardown { Plutonium::Interaction::Run.delete_all }

  # touch? is the default predicate because Blogging::PostPolicy#touch? is
  # unconditionally true — it keeps every test that is NOT about permission from
  # accidentally depending on one.
  def create_run!(target_ids:, organization: @org, initiator: @user, namespace: nil,
    policy_class_name: "Blogging::PostPolicy", policy_action: "touch?", **attrs)
    TestPostRun.create!(
      initiator: initiator,
      scoped_entity: organization,
      target_type: "Blogging::Post",
      target_ids: target_ids,
      authorization_namespace: namespace,
      policy_class_name: policy_class_name,
      policy_action: policy_action,
      **attrs
    )
  end

  def create_user_run!(target_ids:, namespace:, policy_class_name:, organization: @org, initiator: @user)
    TestUserRun.create!(
      initiator: initiator,
      scoped_entity: organization,
      target_type: "User",
      target_ids: target_ids,
      authorization_namespace: namespace,
      policy_class_name: policy_class_name,
      policy_action: "read?"
    )
  end

  # Counts real statements, dropping the schema reflection and BEGIN/COMMIT
  # noise that would otherwise swamp the signal.
  def capture_sql
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name])
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "resolves targets inside the stored entity scope" do
    context = Context.new(create_run!(target_ids: [@post.id]))
    targets = context.targets

    assert_equal [@post], targets.records
    assert_empty targets.missing_ids
    assert_empty targets.unauthorized_ids
  end

  # Revoked PERMISSION, as distinct from revoked visibility. Both records are in
  # the scope; only one passes the predicate. Resolving by scope alone would
  # perform the work on both.
  test "a visible target the initiator may no longer act on lands in unauthorized_ids" do
    published = create_post!(user: @user, organization: @org, status: :published)
    draft = create_post!(user: @user, organization: @org, status: :draft)

    # Blogging::PostPolicy#archive? is `record.published?`.
    run = create_run!(target_ids: [published.id, draft.id], policy_action: "archive?")
    context = Context.new(run)

    # Precondition: this is a permission failure, NOT a visibility one — the
    # draft really is inside the scope.
    assert_includes context.authorized_scope.pluck(:id), draft.id

    targets = context.targets

    assert_equal [published], targets.records
    assert_equal [draft.id], targets.unauthorized_ids,
      "a target the initiator can still see but may no longer act on must be " \
      "reported, not performed"
    assert_empty targets.missing_ids
  end

  # The executor calls this per record immediately before acting, so it has to
  # be reachable from outside.
  test "permitted? is public and answers the recorded predicate per record" do
    published = create_post!(user: @user, organization: @org, status: :published)
    draft = create_post!(user: @user, organization: @org, status: :draft)
    context = Context.new(create_run!(target_ids: [published.id], policy_action: "archive?"))

    assert context.permitted?(published)
    refute context.permitted?(draft)
  end

  test "permitted? raises rather than returning false when the predicate is gone" do
    context = Context.new(create_run!(target_ids: [@post.id], policy_action: "nonexistent_action?"))

    # A renamed action must not degrade into a silent "not allowed" that skips
    # every target and reports a clean run.
    assert_raises(NotImplementedError) { context.permitted?(@post) }
  end

  # Without refresh_subjects!, initiator and scoped_entity are cached on the run
  # from construction, so a predicate reading subject state cannot see a mid-run
  # change. This is the staleness the executor has to be able to defeat.
  test "refresh_subjects! re-reads the initiator so predicates see mid-run changes" do
    context = Context.new(create_run!(target_ids: [@post.id]))
    original_email = context.initiator.email

    # Change the subject behind the context's back, as a revocation would.
    User.where(id: @user.id).update_all(email: "changed_#{SecureRandom.hex(4)}@example.com")

    assert_equal original_email, context.initiator.email,
      "precondition: the association is cached, which is exactly the problem"

    context.refresh_subjects!

    refute_equal original_email, context.initiator.email
    assert_equal User.find(@user.id).email, context.initiator.email
  end

  test "refresh_subjects! refuses to continue when the initiator is deleted mid-run" do
    run = create_run!(target_ids: [@post.id])
    context = Context.new(run)

    run.update_columns(initiator_id: "999999999")

    error = assert_raises(Context::UnresolvableError) { context.refresh_subjects! }
    assert_match(/no initiator/, error.message)
  end

  test "refresh_subjects! refuses to continue when the tenant is deleted mid-run" do
    run = create_run!(target_ids: [@post.id])
    context = Context.new(run)

    run.update_columns(scoped_entity_id: "999999999")

    error = assert_raises(Context::UnresolvableError) { context.refresh_subjects! }
    assert_match(/no longer exists/, error.message)
  end

  test "refresh_subjects! is safe on a run with no tenant" do
    context = Context.new(create_run!(target_ids: [@post.id], organization: nil))

    context.refresh_subjects!

    assert_nil context.scoped_entity
    assert_equal [@post], context.targets.records
  end

  test "a renamed target model raises a domain error naming the run" do
    run = create_run!(target_ids: [@post.id])
    run.update_columns(target_type: "Blogging::Vanished")

    error = assert_raises(Context::UnresolvableError) { Context.new(run.reload) }
    assert_match(/recorded target_type "Blogging::Vanished"/, error.message)
    assert_match(/run #{run.id}/, error.message)
  end

  test "a renamed authorization namespace raises a domain error naming the run" do
    run = create_run!(target_ids: [@post.id], namespace: "VanishedPortal")

    error = assert_raises(Context::UnresolvableError) { Context.new(run.reload) }
    assert_match(/recorded authorization_namespace "VanishedPortal"/, error.message)
  end

  test "a targeted run that recorded no policy_action refuses to run" do
    run = create_run!(target_ids: [@post.id])
    run.update_columns(policy_action: nil)

    error = assert_raises(Context::UnresolvableError) { Context.new(run.reload) }
    assert_match(/no policy_action/, error.message)
  end

  # THE test. Resolving through anything other than the policy scope — a plain
  # `Blogging::Post.where(id: ids)`, say — returns @other_post here, and a run
  # dispatched inside one tenant silently mutates another's records.
  test "a target in another tenant is NOT returned, and IS reported missing" do
    run = create_run!(target_ids: [@post.id, @other_post.id], organization: @org)
    targets = Context.new(run).targets

    assert_equal [@post], targets.records,
      "cross-tenant leak: a target belonging to #{@other_org.name} was resolved " \
      "for a run scoped to #{@org.name}"
    refute_includes targets.records, @other_post
    assert_equal [@other_post.id], targets.missing_ids
  end

  # The mirror image, so the test above cannot pass merely because the scope is
  # empty or the entity filter is inverted: swap the run's tenant and the other
  # post is the one that resolves.
  test "the same ids resolve to the other record under the other tenant" do
    run = create_run!(target_ids: [@post.id, @other_post.id], organization: @other_org)
    targets = Context.new(run).targets

    assert_equal [@other_post], targets.records
    assert_equal [@post.id], targets.missing_ids
  end

  test "a target whose record no longer exists is reported missing, not dropped" do
    gone = create_post!(user: @user, organization: @org)
    gone_id = gone.id
    gone.destroy!

    targets = Context.new(create_run!(target_ids: [@post.id, gone_id])).targets

    assert_equal [@post], targets.records
    assert_equal [gone_id], targets.missing_ids,
      "a vanished target must be reported; silence makes an under-applied run " \
      "indistinguishable from a complete one"
  end

  test "records come back in the stored target order" do
    second = create_post!(user: @user, organization: @org)
    third = create_post!(user: @user, organization: @org)
    ordered = [third.id, @post.id, second.id]

    targets = Context.new(create_run!(target_ids: ordered)).targets

    assert_equal ordered, targets.records.map(&:id)
  end

  test "ids stored as strings still match integer primary keys" do
    run = create_run!(target_ids: [@post.id.to_s, @other_post.id.to_s])
    targets = Context.new(run).targets

    assert_equal [@post], targets.records
    assert_equal [@other_post.id.to_s], targets.missing_ids
  end

  test "resolves the whole set in a single query against the target table" do
    posts = 20.times.map { create_post!(user: @user, organization: @org) }
    context = Context.new(create_run!(target_ids: posts.map(&:id)))

    statements = capture_sql { context.targets }
    target_queries = statements.grep(/#{Blogging::Post.table_name}/)

    assert_equal 1, target_queries.size,
      "expected one query against #{Blogging::Post.table_name}, got #{target_queries.size}:\n" \
      "#{target_queries.join("\n")}"
  end

  test "query count does not grow with the number of targets" do
    one = Context.new(create_run!(target_ids: [@post.id]))
    many = Context.new(create_run!(target_ids: 20.times.map { create_post!(user: @user, organization: @org).id }))

    assert_equal capture_sql { one.targets }.size, capture_sql { many.targets }.size
  end

  test "a run with no scoped entity resolves without a tenant filter" do
    run = create_run!(target_ids: [@post.id, @other_post.id], organization: nil)
    context = Context.new(run)

    assert_nil context.scoped_entity
    assert_nil run.scoped_entity_type

    targets = context.targets

    # nil means "no tenant", not "tenant unknown" — an unscoped portal has none,
    # so the base policy's scope is the whole answer. Both resolve, and neither
    # is quietly dropped.
    assert_equal [@post, @other_post], targets.records
    assert_empty targets.missing_ids
  end

  test "refuses to resolve when the stored scoped entity has been deleted" do
    # Written as a dangling reference rather than an actual destroy because that
    # is the state a hard-deleted tenant leaves behind, and it avoids dragging
    # the organization's FK graph into the assertion.
    run = create_run!(target_ids: [@post.id])
    run.update_columns(scoped_entity_type: "Organization", scoped_entity_id: "999999999")
    run.reload

    assert_nil run.scoped_entity, "precondition: the association must resolve to nil"

    error = assert_raises(Context::UnresolvableError) { Context.new(run) }
    assert_match(/no longer exists/, error.message)
  end

  test "refuses to resolve when the initiator has been deleted" do
    run = create_run!(target_ids: [@post.id])
    run.update_columns(initiator_type: "User", initiator_id: "999999999")
    run.reload

    error = assert_raises(Context::UnresolvableError) { Context.new(run) }
    assert_match(/no initiator/, error.message)
  end

  test "rebuilds the (user, entity_scope) pair Plutonium authorizes on" do
    context = Context.new(create_run!(target_ids: [@post.id]))

    assert_equal({user: @user, entity_scope: @org}, context.policy_context)
    assert_equal Blogging::Post, context.target_class
  end

  test "builds the target's policy with the rebuilt context" do
    context = Context.new(create_run!(target_ids: [@post.id]))
    policy = context.policy_for(@post)

    assert_kind_of Blogging::PostPolicy, policy
    assert_equal @user, policy.user
    assert_equal @org, policy.entity_scope
    # The record must be passed POSITIONALLY. A `record:` keyword is silently
    # swallowed by ActionPolicy::Policy::Core#initialize, leaving this nil and
    # breaking every predicate that inspects record state.
    assert_equal @post, policy.record
  end

  # Opaque work has no target resource and no per-record predicate, so neither
  # the policy assertion nor the predicate requirement applies to it — building
  # the context must succeed.
  test "an opaque run needs no recorded policy or policy_action" do
    run = TestReportRun.create!(initiator: @user, scoped_entity: @org, target_ids: [])
    context = Context.new(run)

    assert_nil context.policy_action
    assert_nil run.policy_class_name
    refute run.targeted?

    assert_raises(Context::UnresolvableError) { context.targets }
  end

  test "a nil namespace resolves the top-level policy" do
    context = Context.new(create_run!(target_ids: [@post.id], namespace: nil))

    # nil is a legitimate value meaning "top level", not a missing one.
    assert_nil context.authorization_namespace
    assert_equal ::Blogging::PostPolicy, context.target_policy_class
    assert_equal [@post], context.targets.records
  end

  # The gap this class was written with is CLOSED: a run dispatched under a
  # portal namespace resolves that portal's policy, including its narrower scope.
  #
  # User/OrgPortal is the vehicle rather than Post/StorefrontPortal because
  # OrgPortal::UserPolicy narrows through the `relation_scope do |relation|`
  # MACRO, which is the form ActionPolicy dispatches to. (StorefrontPortal's
  # post policy writes `def relation_scope(relation)` as a plain instance
  # method, which ActionPolicy never calls — so it could not demonstrate
  # anything. See the report accompanying this change.)
  test "a namespaced run resolves the PORTAL policy and its narrower scope" do
    colleague = create_user!
    create_membership!(organization: @org, user: @user)
    create_membership!(organization: @org, user: colleague)
    ids = [@user.id, colleague.id]

    # Setup, and the thing that makes the assertions below mean something: the
    # two policies genuinely differ.
    assert_equal ::UserPolicy, ::ActionPolicy.lookup(::User)
    assert_equal ::OrgPortal::UserPolicy, ::ActionPolicy.lookup(::User, namespace: ::OrgPortal)

    top_level = Context.new(
      create_user_run!(target_ids: ids, namespace: nil, policy_class_name: "UserPolicy")
    )
    assert_equal ::UserPolicy, top_level.target_policy_class
    assert_equal ids.sort, top_level.targets.records.map(&:id).sort

    scoped = Context.new(
      create_user_run!(target_ids: ids, namespace: "OrgPortal", policy_class_name: "OrgPortal::UserPolicy")
    )
    assert_equal ::OrgPortal::UserPolicy, scoped.target_policy_class
    assert_equal [@user.id], scoped.targets.records.map(&:id),
      "the portal policy narrows to the initiator alone; resolving the base " \
      "policy instead would have returned the colleague too"
    assert_equal [colleague.id], scoped.targets.missing_ids
  end

  test "a run whose recorded policy no longer matches refuses to run" do
    # Stands in for a policy renamed, deleted or re-parented between enqueue and
    # perform: today's lookup returns something other than what dispatch saw.
    run = create_run!(target_ids: [@post.id], policy_class_name: "StorefrontPortal::Blogging::PostPolicy")

    error = assert_raises(Context::PolicyMismatchError) { Context.new(run) }
    assert_match(/dispatched under StorefrontPortal::Blogging::PostPolicy/, error.message)
    assert_match(/now resolves to Blogging::PostPolicy/, error.message)
    # Rescuable as the general "this run cannot be trusted" case.
    assert_kind_of Context::UnresolvableError, error
  end

  test "a targeted run that recorded no policy refuses to run" do
    run = create_run!(target_ids: [@post.id])
    run.update_columns(policy_class_name: nil)

    error = assert_raises(Context::UnresolvableError) { Context.new(run.reload) }
    assert_match(/unverifiable policy/, error.message)
  end

  test "an STI target does not falsely trip the policy assertion" do
    # Blogging::Article has no Blogging::ArticlePolicy, so lookup falls back to
    # the STI base's Blogging::PostPolicy. Dispatch records the RESULT of that
    # lookup and perform replays the identical lookup, so they agree — the
    # assertion must not punish a perfectly legitimate STI run.
    article = create_article!(user: @user, organization: @org)
    assert_equal ::Blogging::PostPolicy, ::ActionPolicy.lookup(::Blogging::Article)

    run = TestPostRun.create!(
      initiator: @user, scoped_entity: @org,
      target_type: "Blogging::Article", target_ids: [article.id],
      policy_class_name: "Blogging::PostPolicy", policy_action: "touch?"
    )

    assert_equal [article], Context.new(run).targets.records
  end

  test "a per-record STI policy may differ from the run's policy without raising" do
    # The run's assertion is about the TARGET RESOURCE. Individual rows of an STI
    # table can legitimately resolve a different policy, so policy_for must not
    # be asserted — doing so would break this case.
    article = create_article!(user: @user, organization: @org)
    run = create_run!(target_ids: [article.id], namespace: "AdminPortal",
      policy_class_name: "Blogging::PostPolicy")
    context = Context.new(run)

    assert_equal ::Blogging::PostPolicy, context.target_policy_class
    assert_equal ::AdminPortal::Blogging::ArticlePolicy, context.policy_for(article).class
  end
end

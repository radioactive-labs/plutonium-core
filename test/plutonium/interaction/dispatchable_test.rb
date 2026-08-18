# frozen_string_literal: true

require "test_helper"

# Dispatching interactions. Declared at the top level, the way a host app's
# would be — `dispatches_to` has to work in an ordinary class body.
class DispatchBulkInteraction < Plutonium::Resource::Interaction
  dispatches_to TestPostRun

  attribute :resources
  attribute :notify_users, :boolean

  validates :notify_users, inclusion: {in: [true, false]}
end

class DispatchRecordInteraction < Plutonium::Resource::Interaction
  dispatches_to TestPostRun

  attribute :resource
end

# No resource/resources at all: opaque work, which carries no targets and
# therefore no policy assertion.
class DispatchOpaqueInteraction < Plutonium::Resource::Interaction
  dispatches_to TestReportRun

  attribute :report_period, :string
end

class Plutonium::Interaction::DispatchableTest < ActiveSupport::TestCase
  include DataHelpers
  include ActiveJob::TestHelper

  Job = Plutonium::Interaction::Runs::Job
  Context = Plutonium::Interaction::Runs::Context
  Redirect = Plutonium::Interaction::Response::Redirect

  # Mirrors the controller surface an interaction reaches, INCLUDING its
  # visibility, because the visibility is the trap. Rails' helper_method leaves
  # the controller method private and exposes it on `helpers`, so a mock that
  # published everything on the controller would pass whether or not the code
  # goes through the right door — and the door it must not go through returns
  # nil for the tenant, which reads as "no tenant" and resolves targets across
  # every one of them.
  #
  # `authorization_namespace` is the exception: ActionPolicy::Behaviours::
  # Namespaced defines it as a public controller method.
  class MockController
    HELPER_METHODS = %i[
      current_user current_scoped_entity resource_class current_interactive_action resource_url_for
    ].freeze

    attr_writer :current_user, :current_scoped_entity, :resource_class, :current_interactive_action,
      :scoped_to_entity
    attr_accessor :authorization_namespace

    def initialize
      @scoped_to_entity = true
    end

    def scoped_to_entity? = @scoped_to_entity

    def helpers = @helpers ||= HelperProxy.new(self)

    private

    attr_reader :current_user, :resource_class, :current_interactive_action

    # Stands in for the real helper, whose entity-prefixed output is pinned by
    # OrgPortal::DispatchRedirectTest against a live controller — the assertion
    # a mock cannot make.
    def resource_url_for(record) = "/mock/runs/#{record.id}"

    # Mirrors EntityScoping#current_scoped_entity, which RAISES on an unscoped
    # portal rather than returning nil.
    def current_scoped_entity
      raise NotImplementedError, "this request is not scoped to an entity" unless scoped_to_entity?

      @current_scoped_entity
    end

    class HelperProxy
      def initialize(controller)
        @controller = controller
      end

      HELPER_METHODS.each do |name|
        define_method(name) { |*args| @controller.send(name, *args) }
      end
    end
  end

  # A queue that refuses the job, so the enqueue failure is a real one rather
  # than a stubbed method.
  class RaisingQueueAdapter
    def enqueue(*) = raise "queue is down"

    def enqueue_at(*) = raise "queue is down"
  end

  class MockViewContext
    attr_reader :controller

    def initialize(controller)
      @controller = controller
    end
  end

  # This suite has NO transactional rollback — test_helper.rb never loads
  # rails/test_help — so rows persist across tests. The runs table is cleared
  # explicitly; every other assertion is pinned to records this test created.
  setup do
    Plutonium::Interaction::Run.delete_all

    @user = create_user!
    @org = create_organization!
    @other_org = create_organization!
    @post = create_post!(user: @user, organization: @org, title: "First")
    @second_post = create_post!(user: @user, organization: @org, title: "Second")

    @controller = MockController.new
    @controller.current_user = @user
    @controller.current_scoped_entity = @org
    @controller.resource_class = Blogging::Post
    # Blogging::PostPolicy#touch? is unconditionally true, so nothing here
    # accidentally depends on a permission.
    @controller.current_interactive_action = interactive_action(:touch)
    @view_context = MockViewContext.new(@controller)
  end

  teardown { Plutonium::Interaction::Run.delete_all }

  def interactive_action(name, interaction: DispatchBulkInteraction)
    Plutonium::Action::Interactive.new(name, interaction: interaction, immediate: false)
  end

  def dispatch_bulk(resources: nil, **attributes)
    DispatchBulkInteraction.call(
      view_context: @view_context,
      resources: resources || [@post, @second_post],
      notify_users: true,
      **attributes
    )
  end

  # --- the row dispatch writes ---------------------------------------------

  test "a bulk dispatch persists the run, its options and its targets" do
    outcome = nil
    assert_difference -> { Plutonium::Interaction::Run.count }, 1 do
      outcome = dispatch_bulk
    end

    assert outcome.success?
    run = outcome.value

    assert_instance_of TestPostRun, run
    assert_equal "pending", run.state
    assert_equal @user, run.initiator
    assert_equal @org, run.scoped_entity
    assert_equal "Blogging::Post", run.target_type
    assert_equal [@post.id, @second_post.id], run.target_ids
    assert_equal 2, run.progress_total
  end

  test "the validated attributes land in options, without the records" do
    run = dispatch_bulk.value

    assert_equal({"notify_users" => true}, run.options,
      "the targets are re-resolved through the policy scope at perform time; " \
      "a serialized copy in options would be both stale and unauthorized")
  end

  test "dispatch records the policy it actually resolved, not an inferred name" do
    run = dispatch_bulk.value

    assert_nil run.authorization_namespace, "a top-level dispatch has no namespace"
    assert_equal "Blogging::PostPolicy", run.policy_class_name
    assert_equal "touch?", run.policy_action
  end

  test "a namespaced dispatch records the portal's module name and its policy" do
    @controller.authorization_namespace = OrgPortal

    run = dispatch_bulk.value

    # The module's NAME — the column is a string, and Runs::Context
    # constantizes it back.
    assert_equal "OrgPortal", run.authorization_namespace
    assert_equal "OrgPortal::Blogging::PostPolicy", run.policy_class_name
  end

  test "a record action dispatches its single target" do
    run = DispatchRecordInteraction.call(view_context: @view_context, resource: @post).value

    assert_equal "Blogging::Post", run.target_type
    assert_equal [@post.id], run.target_ids
    assert_equal 1, run.progress_total
    assert_empty run.options
  end

  test "an opaque run persists no targets and no policy assertion" do
    run = DispatchOpaqueInteraction.call(view_context: @view_context, report_period: "monthly").value

    assert_instance_of TestReportRun, run
    assert_nil run.target_type
    assert_empty run.target_ids
    assert_nil run.progress_total, "nil is INDETERMINATE; opaque work has no denominator"
    assert_nil run.policy_class_name
    assert_nil run.policy_action
    assert_equal({"report_period" => "monthly"}, run.options)
    # Still the two authorization subjects: an opaque run authorizes as someone,
    # in a tenant.
    assert_equal @user, run.initiator
    assert_equal @org, run.scoped_entity
  end

  test "a portal with no tenant dispatches a run with no scoped entity" do
    @controller.scoped_to_entity = false

    run = dispatch_bulk.value

    assert_nil run.scoped_entity_type,
      "nil must mean NO tenant, so the type column has to be empty too — a " \
      "populated type with a nil association is how Runs::Context detects a " \
      "DELETED tenant and refuses to run"
    assert_nil run.scoped_entity
  end

  # --- the outcome ---------------------------------------------------------

  test "the outcome is a success that redirects to the run" do
    outcome = dispatch_bulk

    assert outcome.success?
    response = outcome.to_response
    assert_instance_of Redirect, response
    # A resolved URL, not the bare record: Response::Redirect would put the
    # record through a plain url_for, which cannot build the entity-prefixed
    # helper an entity-scoped portal routes runs under.
    assert_equal ["/mock/runs/#{outcome.value.id}"], response.instance_variable_get(:@args)
  end

  # --- the enqueue ---------------------------------------------------------

  test "dispatch enqueues the job with nothing but the run id" do
    run = nil
    assert_enqueued_jobs 1, only: Job do
      run = dispatch_bulk.value
    end

    assert_enqueued_with(job: Job, args: [run.id])
  end

  test "the job is enqueued on the configured queue" do
    Plutonium.configuration.interaction_runs.queue = :low

    assert_enqueued_with(job: Job, queue: "low") { dispatch_bulk }
  ensure
    Plutonium.configuration.interaction_runs.queue = :default
  end

  test "a validation failure persists nothing and enqueues nothing" do
    outcome = nil
    assert_no_difference -> { Plutonium::Interaction::Run.count } do
      assert_no_enqueued_jobs do
        outcome = dispatch_bulk(notify_users: nil)
      end
    end

    assert outcome.failure?
  end

  # --- the seam with Runs::Context -----------------------------------------

  # The whole point of the recorded triple. Runs::Context refuses a row whose
  # policy disagrees with today's lookup, whose namespace no longer resolves, or
  # whose subjects cannot be rebuilt — so simply CONSTRUCTING one over a
  # dispatched row is the assertion that Task 5 and Task 3 agree.
  test "the persisted row rebuilds into a context that resolves the targets" do
    @controller.authorization_namespace = OrgPortal
    run = dispatch_bulk(resources: [@post, @second_post]).value

    context = Context.new(run.reload)

    assert_equal @user, context.initiator
    assert_equal @org, context.scoped_entity
    assert_equal OrgPortal, context.authorization_namespace
    assert_equal OrgPortal::Blogging::PostPolicy, context.target_policy_class
    assert_equal :touch?, context.policy_action

    targets = context.targets
    assert_equal [@post, @second_post], targets.records
    assert_empty targets.missing_ids
    assert_empty targets.unauthorized_ids
  end

  # The tenant is half of what the policy scope filters on, and it reaches the
  # row through a PRIVATE controller method exposed by helper_method. Read off
  # the controller directly it comes back nil, which is a legitimate value
  # meaning "no tenant" — so the run would resolve targets in every tenant
  # rather than fail. This pins the round trip end to end.
  test "the recorded tenant is what narrows the targets at perform time" do
    other_post = create_post!(user: @user, organization: @other_org, title: "Other tenant")
    run = dispatch_bulk(resources: [@post, other_post]).value

    targets = Context.new(run.reload).targets

    assert_equal [@post], targets.records,
      "cross-tenant leak: the run resolved a record outside the tenant it was " \
      "dispatched in"
    assert_equal [other_post.id], targets.missing_ids
  end

  # --- refusals ------------------------------------------------------------

  # The predicate is what lets perform re-check PERMISSION rather than mere
  # visibility, so a targeted run cannot be written without one. Runs::Context
  # would refuse the row later anyway, but by then the diagnosis is a line in a
  # failed job, hours from the code that wrote it.
  test "dispatch refuses to write a targeted run with no policy predicate" do
    @controller.current_interactive_action = nil

    error = assert_raises(RuntimeError) { dispatch_bulk }

    assert_match(/no interactive action is in flight/, error.message)
    assert_match(/DispatchBulkInteraction dispatches TestPostRun/, error.message)
    assert_match(/cannot re-check permission/, error.message)
    assert_equal 0, Plutonium::Interaction::Run.count, "nothing may be persisted"
  end

  # A bulk submission whose ids have all been deleted or left the tenant since
  # the index rendered. Reading that as "no targets" would write a run with no
  # target_type and no policy assertion — indistinguishable from genuinely
  # opaque work, and refused deep inside the job instead of here.
  test "dispatch refuses an empty selection rather than downgrading it to opaque work" do
    error = assert_raises(RuntimeError) { dispatch_bulk(resources: []) }

    assert_match(/declares a subject but resolved no records/, error.message)
    assert_match(/must not be silently downgraded to opaque work/, error.message)
    assert_equal 0, Plutonium::Interaction::Run.count
  end

  test "dispatches_to refuses to overwrite an interaction's own execute" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Interaction) do
        def execute = succeed(:inline)

        dispatches_to TestPostRun
      end
    end

    assert_match(/defines its own #execute/, error.message)
    assert_match(/does the work inline or dispatches it to a run/, error.message)
  end

  # The reverse ordering: def execute written below dispatches_to used to
  # win silently via ordinary Ruby override semantics.
  test "an execute defined after dispatches_to does not silently override it" do
    klass = Class.new(Plutonium::Resource::Interaction) do
      dispatches_to TestPostRun

      attribute :resource

      def execute = succeed(:inline)
    end

    run = klass.call(view_context: @view_context, resource: @post).value

    assert_kind_of Plutonium::Interaction::Run, run,
      "dispatches_to's #execute must still win over a same-class #execute defined afterwards"
  end

  # The row is committed before the enqueue, so a queue that refuses the job
  # leaves a run nothing will ever pick up. It has to stop looking pending.
  test "a run whose enqueue fails is marked failed rather than left pending" do
    run_count_before = Plutonium::Interaction::Run.count
    original_adapter = Job.queue_adapter
    Job.queue_adapter = RaisingQueueAdapter.new

    error = assert_raises(RuntimeError) { dispatch_bulk }

    assert_equal "queue is down", error.message, "the failure must still surface"
    assert_equal run_count_before + 1, Plutonium::Interaction::Run.count

    run = Plutonium::Interaction::Run.last
    assert_equal "failed", run.state
    assert_match(/could not be enqueued/, run.errors_log.first["message"])
  ensure
    Job.queue_adapter = original_adapter
  end

  # --- the declaration -----------------------------------------------------

  test "a non-dispatching interaction is untouched" do
    interaction = Class.new(Plutonium::Resource::Interaction)

    assert_nil interaction.run_class
    assert_raises(NotImplementedError) { interaction.new(view_context: @view_context).call }
  end

  test "a subclass inherits the declaration" do
    subclass = Class.new(DispatchBulkInteraction)

    assert_equal TestPostRun, subclass.run_class

    run = subclass.call(view_context: @view_context, resources: [@post], notify_users: false).value
    assert_instance_of TestPostRun, run
  end
end

# frozen_string_literal: true

require "test_helper"

# Dispatching interactions. Declared at the top level, the way a host app's
# would be — `async` has to work in an ordinary class body.
class DispatchBulkInteraction < Plutonium::Resource::Interaction
  async TestPostRun

  attribute :resources
  attribute :notify_users, :boolean

  validates :notify_users, inclusion: {in: [true, false]}
end

class DispatchRecordInteraction < Plutonium::Resource::Interaction
  async TestPostRun

  attribute :resource
end

# No resource/resources at all: opaque work, which carries no targets and
# therefore no policy assertion.
class DispatchOpaqueInteraction < Plutonium::Resource::Interaction
  async TestReportRun

  attribute :report_period, :string
end

# The block form: run declared inline, no second file and no name to choose.
class InlineArchiveInteraction < Plutonium::Resource::Interaction
  attribute :resources
  attribute :reason, :string

  async do
    on_failure :continue
    cattr_accessor :performed
    def perform_on(post) = self.class.performed << "#{post.id}/#{options["reason"]}"
  end
end

# Typed and file-valued attributes — neither survives a JSON column untouched.
class TypedDispatchInteraction < Plutonium::Resource::Interaction
  attribute :note, :string
  attribute :count, :integer
  attribute :starts_on, :date
  attribute :amount, :decimal
  attribute :import_file

  async { def perform = :ok }
end

class Plutonium::Interaction::DispatchableTest < ActiveSupport::TestCase
  include DataHelpers
  include ActiveJob::TestHelper

  Job = Plutonium::Interaction::Async::Job
  Context = Plutonium::Interaction::Async::Context
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
      current_parent current_nested_association
    ].freeze

    attr_writer :current_user, :current_scoped_entity, :resource_class, :current_interactive_action,
      :scoped_to_entity, :current_parent, :current_nested_association
    attr_accessor :authorization_namespace

    def initialize
      @scoped_to_entity = true
    end

    def scoped_to_entity? = @scoped_to_entity

    def helpers = @helpers ||= HelperProxy.new(self)

    private

    attr_reader :current_user, :resource_class, :current_interactive_action,
      :current_parent, :current_nested_association

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

    # Part of the adapter contract since Rails 7.2, and ActiveJob calls it
    # before enqueuing. Without it the double raises NoMethodError instead of
    # the "queue is down" this test is about — which passed on Rails 8, where
    # the call is guarded, and failed only on Rails 7.
    #
    # false, not true: true defers the enqueue to after the transaction commits,
    # and the failure this test asserts is the one raised at the call site.
    def enqueue_after_transaction_commit? = false
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
    Plutonium::Interaction::Async::Run.delete_all

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

  teardown { Plutonium::Interaction::Async::Run.delete_all }

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
    assert_difference -> { Plutonium::Interaction::Async::Run.count }, 1 do
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

  test "dispatching while runs are disabled names the switch instead of the missing table" do
    Plutonium.configuration.async_interactions.enabled = false

    error = assert_raises(Plutonium::Interaction::Concerns::Dispatchable::NotEnabledError) { dispatch_bulk }

    # The flag gates the MIGRATION as well as the behaviour, so with it off the
    # table does not exist. Left unguarded this surfaces as a raw
    # ActiveRecord::StatementInvalid "no such table", which says nothing about
    # the one line of configuration that fixes it.
    assert_match(/async interactions are not enabled/, error.message)
    assert_match(/async_interactions\.enabled = true/, error.message)
    assert_equal 0, Plutonium::Interaction::Async::Run.count
  ensure
    Plutonium.configuration.async_interactions.enabled = true
  end

  test "typed attributes keep their types across the options column" do
    run = TypedDispatchInteraction.call(
      view_context: @view_context, note: "x", count: 3,
      starts_on: "2026-08-19", amount: "12.34"
    ).value

    options = Plutonium::Interaction::Async::Run.find(run.id).options

    assert_equal "x", options["note"]
    assert_equal 3, options["count"]
    # Raw JSON hands both of these back as Strings, and `options["amount"] * 2`
    # then quietly produces "12.3412.34".
    assert_equal Date.new(2026, 8, 19), options["starts_on"]
    assert_equal BigDecimal("12.34"), options["amount"]
  end

  test "primitives are stored verbatim, not wrapped in a serializer envelope" do
    run = TypedDispatchInteraction.call(
      view_context: @view_context, note: "x", count: 3
    ).value

    raw = Plutonium::Interaction::Async::Run.where(id: run.id).pick(:options)
    raw = JSON.parse(raw) if raw.is_a?(String)

    assert_equal "x", raw["note"], "a String must stay readable in the column"
    assert_equal 3, raw["count"]
  end

  test "an uploaded file is staged to a token and revived at perform time" do
    file = Rack::Test::UploadedFile.new(
      StringIO.new("a,b\n1,2\n"), "text/csv", original_filename: "import.csv"
    )

    run = TypedDispatchInteraction.call(
      view_context: @view_context, import_file: file
    ).value
    run = Plutonium::Interaction::Async::Run.find(run.id)

    # The tempfile is gone once the request ends, so what is stored has to be a
    # token the backend can revive — never the file itself.
    assert_kind_of String, run.options["import_file"]
    refute_match(/tempfile/, run.options["import_file"])

    revived = run.attachment(:import_file)
    assert_equal "import.csv", revived.filename
    # The bytes are the point — a run that gets the filename and nothing to read
    # is exactly the failure staging exists to prevent.
    assert_equal "a,b\n1,2\n", revived.download
    revived.open { |f| assert_equal "a,b\n1,2\n", f.read }
  end

  test "an attribute that cannot be carried is refused at dispatch" do
    interaction = Class.new(Plutonium::Resource::Interaction) do
      def self.name = "UncarryableInteraction"
      attribute :thing
      async { def perform = :ok }
    end

    error = assert_raises(ArgumentError) do
      interaction.call(view_context: @view_context, thing: Object.new)
    end

    # Named where the author declared it, rather than surviving into a row whose
    # work fails deep in a job.
    assert_match(/cannot carry one of its attributes/, error.message)
  end

  test "the validated attributes land in options, without the records" do
    run = dispatch_bulk.value

    assert_equal({"notify_users" => true}, run.options,
      "the targets are re-resolved through the policy scope at perform time; " \
      "a serialized copy in options would be both stale and unauthorized")
  end

  test "a nested dispatch records the parent and the association it hangs off" do
    @controller.current_parent = @post
    @controller.current_nested_association = :comments

    run = dispatch_bulk.value

    assert_equal @post, run.parent
    # A string, because the column is one — Context symbolizes it back.
    assert_equal "comments", run.parent_association
  end

  test "a dispatch from a non-nested route records no parent" do
    run = dispatch_bulk.value

    assert_nil run.parent_type, "nil means NOT NESTED, and must not read as a lost parent"
    assert_nil run.parent_association
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

    # The module's NAME — the column is a string, and Async::Context
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
      "populated type with a nil association is how Async::Context detects a " \
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
    Plutonium.configuration.async_interactions.queue = :low

    assert_enqueued_with(job: Job, queue: "low") { dispatch_bulk }
  ensure
    Plutonium.configuration.async_interactions.queue = :default
  end

  test "a validation failure persists nothing and enqueues nothing" do
    outcome = nil
    assert_no_difference -> { Plutonium::Interaction::Async::Run.count } do
      assert_no_enqueued_jobs do
        outcome = dispatch_bulk(notify_users: nil)
      end
    end

    assert outcome.failure?
  end

  # --- the seam with Async::Context -----------------------------------------

  # The whole point of the recorded triple. Async::Context refuses a row whose
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
  # visibility, so a targeted run cannot be written without one. Async::Context
  # would refuse the row later anyway, but by then the diagnosis is a line in a
  # failed job, hours from the code that wrote it.
  test "dispatch refuses to write a targeted run with no policy predicate" do
    @controller.current_interactive_action = nil

    error = assert_raises(RuntimeError) { dispatch_bulk }

    assert_match(/no interactive action is in flight/, error.message)
    assert_match(/DispatchBulkInteraction dispatches TestPostRun/, error.message)
    assert_match(/cannot re-check permission/, error.message)
    assert_equal 0, Plutonium::Interaction::Async::Run.count, "nothing may be persisted"
  end

  # A bulk submission whose ids have all been deleted or left the tenant since
  # the index rendered. Reading that as "no targets" would write a run with no
  # target_type and no policy assertion — indistinguishable from genuinely
  # opaque work, and refused deep inside the job instead of here.
  test "dispatch refuses an empty selection rather than downgrading it to opaque work" do
    error = assert_raises(RuntimeError) { dispatch_bulk(resources: []) }

    assert_match(/declares a subject but resolved no records/, error.message)
    assert_match(/must not be silently downgraded to opaque work/, error.message)
    assert_equal 0, Plutonium::Interaction::Async::Run.count
  end

  test "a block declares a run class, named so its type can be read back" do
    run_class = InlineArchiveInteraction.run_class

    assert_equal InlineArchiveInteraction::Run, run_class
    assert_operator run_class, :<, Plutonium::Interaction::Async::Run
    # NAMED, not anonymous: the class name is persisted in `type` and
    # constantized in the job process, so an anonymous class would write a row
    # nothing could read back.
    assert_equal "InlineArchiveInteraction::Run", run_class.name
    assert_equal :continue, run_class.failure_policy, "macros inside the block apply to the run"
  end

  test "a run declared by a block performs like any other" do
    InlineArchiveInteraction::Run.performed = []
    run = InlineArchiveInteraction.call(
      view_context: @view_context, resources: [@post], reason: "spam"
    ).value

    assert_equal "InlineArchiveInteraction::Run", run.reload.type
    assert_equal InlineArchiveInteraction::Run, Plutonium::Interaction::Async::Run.find(run.id).class

    Plutonium::Interaction::Async::Executor.new(run).call

    assert_equal ["#{@post.id}/spam"], InlineArchiveInteraction::Run.performed,
      "the block's perform_on reaches the validated attributes through options"
    assert_equal "completed", run.reload.state
  end

  test "async refuses a run class and a block together" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Interaction) do
        def self.name = "BothFormsInteraction"
        async(TestPostRun) { def perform_on(r) = r }
      end
    end

    assert_match(/both a run class and a block/, error.message)
  end

  test "async refuses to declare nothing to run" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Interaction) do
        def self.name = "EmptyAsyncInteraction"
        async
      end
    end

    assert_match(/nothing to run/, error.message)
  end

  test "async's block refuses to clobber a Run the author declared" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Interaction) do
        def self.name = "OwnRunInteraction"
        const_set(:Run, Class.new(Plutonium::Interaction::Async::Run))
        async { def perform_on(r) = r }
      end
    end

    # Replacing it silently would lose the author's work with no diagnostic.
    assert_match(/already defines/, error.message)
  end

  test "async refuses to overwrite an interaction's own execute" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Resource::Interaction) do
        def execute = succeed(:inline)

        async TestPostRun
      end
    end

    assert_match(/defines its own #execute/, error.message)
    assert_match(/executes inline or runs async/, error.message)
  end

  # The reverse ordering: def execute written below async used to
  # win silently via ordinary Ruby override semantics.
  test "an execute defined after async does not silently override it" do
    klass = Class.new(Plutonium::Resource::Interaction) do
      async TestPostRun

      attribute :resource

      def execute = succeed(:inline)
    end

    run = klass.call(view_context: @view_context, resource: @post).value

    assert_kind_of Plutonium::Interaction::Async::Run, run,
      "async's #execute must still win over a same-class #execute defined afterwards"
  end

  # The row is committed before the enqueue, so a queue that refuses the job
  # leaves a run nothing will ever pick up. It has to stop looking pending.
  test "a run whose enqueue fails is marked failed rather than left pending" do
    run_count_before = Plutonium::Interaction::Async::Run.count
    original_adapter = Job.queue_adapter
    Job.queue_adapter = RaisingQueueAdapter.new

    error = assert_raises(RuntimeError) { dispatch_bulk }

    assert_equal "queue is down", error.message, "the failure must still surface"
    assert_equal run_count_before + 1, Plutonium::Interaction::Async::Run.count

    run = Plutonium::Interaction::Async::Run.last
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

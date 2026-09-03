# frozen_string_literal: true

require "test_helper"

# Regression guard for `field condition:` and `input condition:` on forms.
#
# The form renderer must honour a `condition:` declared on EITHER `field` or
# `input` and hide the field when the proc returns falsey. A "clean up"
# refactoring moved `field_options.except(:condition)` ABOVE the condition
# read, so `field condition:` was silently ignored — only `input condition:`
# worked (it reads from `input_options`, which was never stripped). This
# exercises both spellings end-to-end through the full render path, the
# object-context evaluation, and the input-over-field precedence.
class AdminPortal::FormFieldConditionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    @org = create_organization!
    @sink = KitchenSink.create!(name: "Cond", organization: @org)

    # Snapshot the class-level definition stores so per-test mutations to
    # KitchenSinkDefinition cannot leak into other tests (notably the wizard
    # flow, which imports KitchenSink fields).
    @saved_fields = KitchenSinkDefinition.defined_fields.deep_dup
    @saved_inputs = KitchenSinkDefinition.defined_inputs.deep_dup
  end

  teardown do
    KitchenSinkDefinition.instance_variable_set(:@defined_fields, @saved_fields)
    KitchenSinkDefinition.instance_variable_set(:@defined_inputs, @saved_inputs)
    KitchenSinkDefinition.instance_variable_set(:@merged_defined_fields, nil)
    KitchenSinkDefinition.instance_variable_set(:@merged_defined_inputs, nil)
  end

  def redefine_field(name, **options)
    KitchenSinkDefinition.field(name, **options)
    KitchenSinkDefinition.instance_variable_set(:@merged_defined_fields, nil)
  end

  def redefine_input(name, **options)
    KitchenSinkDefinition.input(name, **options)
    KitchenSinkDefinition.instance_variable_set(:@merged_defined_inputs, nil)
  end

  # ---- `field condition:` (the spelling the bug broke) ----

  test "a falsey field condition hides the field from the rendered form" do
    redefine_field(:description, as: :text, condition: -> { false })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    refute_includes response.body, %(name="kitchen_sink[description]"),
      "a falsey `field condition:` must hide the field"
  end

  test "a truthy field condition still renders the field" do
    redefine_field(:description, as: :text, condition: -> { true })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    assert_includes response.body, %(name="kitchen_sink[description]"),
      "a truthy `field condition:` must render the field"
  end

  # ---- `input condition:` (regression: this never broke) ----

  test "a falsey input condition hides the field from the rendered form" do
    redefine_input(:description, as: :text, condition: -> { false })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    refute_includes response.body, %(name="kitchen_sink[description]"),
      "a falsey `input condition:` must hide the field"
  end

  test "a truthy input condition still renders the field" do
    redefine_input(:description, as: :text, condition: -> { true })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    assert_includes response.body, %(name="kitchen_sink[description]"),
      "a truthy `input condition:` must render the field"
  end

  # ---- evaluation context: the proc runs against the form (`instance_exec`) ----

  test "a field condition is evaluated against the form, so it can read object" do
    # Same condition, two records with different names. The proc reads
    # `object` — proving the condition is instance_exec'd against the form,
    # not collapsed to a boolean at definition-load time.
    redefine_field(:description, as: :text, condition: -> { object.name == "Cond" })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    assert_includes response.body, %(name="kitchen_sink[description]"),
      "condition true for this record should render the field"

    other = KitchenSink.create!(name: "Other", organization: @org)
    get "/admin/kitchen_sinks/#{other.id}/edit"
    assert_response :success
    refute_includes response.body, %(name="kitchen_sink[description]"),
      "condition false for this record should hide the field"
  end

  test "a field condition can branch on a new vs persisted record" do
    # The wizard / show-page analog of this is `collapsed: ->(form)`. `condition:`
    # is the documented exception — it takes NO argument and is instance_exec'd,
    # so `object` resolves against the form.
    redefine_field(:description, as: :text, condition: -> { object.persisted? })

    get "/admin/kitchen_sinks/new"  # new record → not persisted → hidden
    assert_response :success
    refute_includes response.body, %(name="kitchen_sink[description]")

    get "/admin/kitchen_sinks/#{@sink.id}/edit"  # persisted → shown
    assert_response :success
    assert_includes response.body, %(name="kitchen_sink[description]")
  end

  # ---- precedence: `input condition:` wins over `field condition:` ----

  test "an input condition takes precedence over a field condition (truthy field, falsey input)" do
    redefine_field(:description, as: :text, condition: -> { true })
    redefine_input(:description, as: :text, condition: -> { false })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    refute_includes response.body, %(name="kitchen_sink[description]"),
      "input condition (falsey) must win over field condition (truthy)"
  end

  test "an input condition takes precedence over a field condition (falsey field, truthy input)" do
    redefine_field(:description, as: :text, condition: -> { false })
    redefine_input(:description, as: :text, condition: -> { true })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    assert_includes response.body, %(name="kitchen_sink[description]"),
      "input condition (truthy) must win over field condition (falsey)"
  end
end

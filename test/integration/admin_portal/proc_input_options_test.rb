# frozen_string_literal: true

require "test_helper"

# A field/input option may be a proc, resolved on every render so it can vary per
# request instead of being frozen when the definition class loads.
#
# Arity picks the receiver, matching what Phlexi already does for validators:
# a zero-arity proc keeps its own binding, and a one-argument proc is handed the
# form (for `object`, `params`, helpers). This holds on every form; only the
# wizard's zero-arity receiver differs, since a step block closes over a
# throwaway recorder rather than anything useful.
class AdminPortal::ProcInputOptionsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    @sink = KitchenSink.create!(name: "Original", organization: create_organization!)
  end

  teardown { KitchenSinkDefinition.instance_variable_set(:@merged_defined_inputs, nil) }

  def redefine_input(**options)
    KitchenSinkDefinition.input(:name, **options)
    KitchenSinkDefinition.instance_variable_set(:@merged_defined_inputs, nil)
  end

  test "a zero-arity proc option is called and its value rendered" do
    redefine_input(placeholder: -> { "from a proc" })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    assert_response :success
    assert_includes response.body, "from a proc"
    refute_includes response.body, "#<Proc"
  end

  test "a one-argument proc option receives the form, so it can read the record" do
    redefine_input(placeholder: ->(form) { "editing #{form.object.name}" })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    assert_response :success
    assert_includes response.body, "editing Original"
  end

  test "the option is resolved per render, not captured once" do
    redefine_input(placeholder: ->(form) { "editing #{form.object.name}" })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    @sink.update!(name: "Renamed")
    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    assert_includes response.body, "editing Renamed"
  end

  # Rebinding would break an option declared in an interaction's
  # `customize_inputs`, which closes over the interaction.
  test "a zero-arity proc keeps its own binding" do
    owner = Object.new
    def owner.label = "from the closure"
    redefine_input(placeholder: -> { owner.label })

    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    assert_includes response.body, "from the closure"
  end
end

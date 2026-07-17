# frozen_string_literal: true

require "test_helper"

# `column :field, formatter: ->(v) { ... }` is documented as a general column
# option (see the plutonium-resource skill). Only phlexi's String display
# component consumed the `formatter:` — every other component (boolean pill,
# currency, badge, number…) splatted its leftover attributes straight into the
# element, so a `formatter:` Proc handed to a typed column leaked into the HTML
# and Phlex rejected it, 500-ing the whole index.
#
# KitchenSinkDefinition declares `column :active, formatter:` on a BOOLEAN, which
# previously routed through the Boolean pill component and crashed. The formatter
# must receive the RAW value (a real boolean), not a stringified one.
class AdminPortal::ColumnFormatterTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = Organization.create!(name: "Formatter Org #{SecureRandom.hex(4)}")
    @on = KitchenSink.create!(name: "On Sink", status: :active, organization: @org, active: true, age: 42)
    @off = KitchenSink.create!(name: "Off Sink", status: :active, organization: @org, active: false)
  end

  teardown { KitchenSink.delete_all }

  test "a formatter on a boolean column renders without leaking the Proc" do
    get "/admin/kitchen_sinks?view=table"

    assert_response :success
    refute_includes response.body, "#<Proc",
      "the formatter Proc must be consumed, not leaked into the HTML"
  end

  test "the formatter receives the raw value and produces the display string" do
    get "/admin/kitchen_sinks?view=table"

    assert_response :success
    # true -> "Enabled", false -> "Disabled". If the value were stringified
    # before the formatter, `false` would arrive as the truthy string "false"
    # and both rows would read "Enabled".
    assert_includes response.body, "Enabled"
    assert_includes response.body, "Disabled"
  end

  test "a formatter on a display (show page) field renders without leaking the Proc" do
    get "/admin/kitchen_sinks/#{@on.id}"

    assert_response :success
    refute_includes response.body, "#<Proc",
      "the formatter Proc must be consumed, not leaked into the HTML"
    assert_includes response.body, "42 years"
  end
end

# frozen_string_literal: true

require "test_helper"
require "csv"

class AdminPortal::ExportCsvTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @org = Organization.create!(name: "Export Org #{SecureRandom.hex(4)}")
    @user = User.create!(email: "export_#{SecureRandom.hex(4)}@example.com", status: :verified)
    @alpha = Blogging::Post.create!(user: @user, organization: @org, title: "Alpha Post", body: "a", status: :draft)
    @beta = Blogging::Post.create!(user: @user, organization: @org, title: "Beta Post", body: "b", status: :published)
  end

  teardown do
    Blogging::Post.delete_all
    Organization.delete_all
    User.delete_all
  end

  # Authorization — export_csv? defaults to false, so the auto-mounted route
  # is forbidden until a resource opts in. Organization never enables it.
  # Proves both that the route is mounted (we reach the action, not a 404)
  # and that the before_action gate invokes export_csv? on the policy.
  test "export is forbidden for a resource that has not enabled it" do
    get "/admin/organizations/export_csv"
    assert_response :forbidden
  end

  test "export redirects unauthenticated requests to login" do
    logout_admin
    get "/admin/blogging/posts/export_csv"
    assert_response :redirect
  end

  # Happy path — full stack: real route, real policy, real definition,
  # real ActiveRecord find_each, real CSV. Blogging::Post enables export
  # (export_csv? + permitted_attributes_for_export + the `export` DSL) in
  # the dummy app. id is always the first column.
  test "enabled export streams a CSV of all records with id first" do
    get "/admin/blogging/posts/export_csv"

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/posts_\d{4}-\d{2}-\d{2}\.csv/, response.headers["Content-Disposition"])

    table = CSV.parse(response.body)
    assert_equal "Id", table[0].first
    assert_equal "Title", table[0][1]
    titles = table[1..].map { |row| row[1] }
    assert_includes titles, "Alpha Post"
    assert_includes titles, "Beta Post"
    ids = table[1..].map { |row| row.first }
    assert_includes ids, @alpha.id.to_s
  end

  # The dummy app's `export` DSL customizes the status header ("State") and
  # uppercases its value — proves per-field output customization end to end.
  test "export applies the definition export DSL formatting" do
    get "/admin/blogging/posts/export_csv"

    table = CSV.parse(response.body)
    assert_includes table[0], "State"
    state_idx = table[0].index("State")
    assert_includes table[1..].map { |row| row[state_idx] }, "DRAFT"
  end

  # An association column with no `export` block renders the record's display
  # label (display_name_of) — "User #<id>" — never "#<User:0x…>".
  test "export renders association columns as a display label, not an object dump" do
    get "/admin/blogging/posts/export_csv"

    table = CSV.parse(response.body)
    user_idx = table[0].index("User")
    user_cells = table[1..].map { |row| row[user_idx] }
    assert_includes user_cells, "User ##{@user.id}"
    refute(user_cells.any? { |cell| cell.include?("#<") }, "association exported as an object dump")
  end

  # CSV/formula injection: a value beginning with = + - @ is neutralized with
  # a leading single quote so spreadsheet apps treat it as literal text.
  test "export neutralizes spreadsheet formula injection in cell values" do
    Blogging::Post.create!(user: @user, organization: @org, title: "=HYPERLINK(\"http://evil\")", body: "x", status: :draft)
    get "/admin/blogging/posts/export_csv"

    titles = CSV.parse(response.body)[1..].map { |row| row[1] }
    assert_includes titles, "'=HYPERLINK(\"http://evil\")"
    refute_includes titles, "=HYPERLINK(\"http://evil\")"
  end

  # Query respect — the export reuses the index's filtered collection, so
  # the same `?q[search]=` that narrows the table narrows the file.
  test "export respects the current search query" do
    get "/admin/blogging/posts/export_csv?q[search]=Alpha"

    assert_response :success
    titles = CSV.parse(response.body)[1..].map { |row| row[1] }
    assert_includes titles, "Alpha Post"
    refute_includes titles, "Beta Post"
  end

  # Export all — bypasses the current query and streams the entire
  # authorized scope, ignoring filters/search.
  test "export all ignores the search query" do
    get "/admin/blogging/posts/export_csv?all=1&q[search]=Alpha"

    assert_response :success
    assert_match(/posts_all_\d{4}-\d{2}-\d{2}\.csv/, response.headers["Content-Disposition"])
    titles = CSV.parse(response.body)[1..].map { |row| row[1] }
    assert_includes titles, "Alpha Post"
    assert_includes titles, "Beta Post"
  end

  # UI split button — rendered when the policy permits it, opening in a new
  # tab (and so bypassing Turbo).
  test "index page shows the export split button when permitted" do
    get "/admin/blogging/posts"

    assert_response :success
    assert_match %r{/admin/blogging/posts/export_csv}, response.body
    assert_match(/target="_blank"/, response.body)
    assert_match(/>Export</, response.body)
    assert_match(/Export all/, response.body)
    assert_match %r{export_csv\?all=1}, response.body
  end

  # Hidden when the policy does not permit it (Organization never enables).
  test "index page hides the export button for a non-enabled resource" do
    get "/admin/organizations"

    assert_response :success
    refute_match(/export_csv/, response.body)
  end

  test "primary export button carries the current search query" do
    get "/admin/blogging/posts?q[search]=Alpha"

    assert_response :success
    # primary href is export_csv with the q[search] param preserved (url-encoded)
    assert_match %r{export_csv\?[^"]*q%5Bsearch%5D=Alpha}, response.body
  end
end

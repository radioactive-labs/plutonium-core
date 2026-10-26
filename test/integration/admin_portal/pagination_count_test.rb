# frozen_string_literal: true

require "test_helper"

# What the index pays to know its total, per `pagination count:`.
class AdminPortal::PaginationCountTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  PATH = "/admin/blogging/posts?limit=10"

  setup do
    login_as_admin(create_admin!)
    Blogging::Post.delete_all
    org = create_organization!
    user = create_user!
    25.times { create_post!(user:, organization: org) }
  end

  teardown do
    Plutonium.configuration.instance_variable_set(:@pagination, {count: :exact}.freeze)
    Blogging::PostDefinition.pagination_config = nil
  end

  def count_queries(path = PATH)
    sqls = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sqls << payload[:sql] if payload[:sql].include?("COUNT(")
    end
    get path
    assert_response :success
    sqls.select { |sql| sql.include?("blogging_posts") }
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  test "exact: a full COUNT and the total in the footer" do
    counts = count_queries
    assert_equal 1, counts.size
    refute_match(/LIMIT/, counts.first)
    assert_includes response.body, "of <b>25</b> in total"
    assert_includes response.body, "25 results"
  end

  test "capped: counts over a LIMIT subquery and shows N+ past the cap" do
    Plutonium.configuration.pagination = {count: 20}

    counts = count_queries
    assert_equal 1, counts.size
    assert_match(/LIMIT/, counts.first)
    assert_includes response.body, "of <b>20+</b> in total"
    assert_includes response.body, "20+ results"
    assert_includes response.body, "page=2", "pages up to the cap stay linked"
    refute_includes response.body, "page=3", "pages past the cap are not linked"
  end

  test "capped: below the cap the total is exact" do
    Plutonium.configuration.pagination = {count: 100}

    count_queries
    assert_includes response.body, "of <b>25</b> in total"
    refute_includes response.body, "25+"
  end

  test "countless: no COUNT query and no total" do
    Plutonium.configuration.pagination = {count: false}

    assert_empty count_queries
    assert_includes response.body, "Displaying Posts <b>1</b>-<b>10</b>"
    refute_includes response.body, "in total"
    refute_includes response.body, "results"
    assert_includes response.body, "page=2", "a next page is linked"
  end

  test "countless: the last page is found by fetching one extra row" do
    Plutonium.configuration.pagination = {count: false}

    count_queries("#{PATH}&page=3")
    assert_includes response.body, "Displaying Posts <b>21</b>-<b>25</b>"
  end

  test "countless: a single page shows its rows as the total" do
    Plutonium.configuration.pagination = {count: false}

    count_queries("/admin/blogging/posts?limit=50")
    assert_includes response.body, "Displaying <b>25</b> Posts"
  end

  # The per-request override from the docs (Definition › Pagination count).
  test "a controller can choose the count per request" do
    AdminPortal::Blogging::PostsController.class_eval do
      private def pagination_count
        current_query_object.active_filter_descriptions.empty? ? false : 10_000
      end
    end

    assert_empty count_queries, "no filter: countless"
    assert_equal 1, count_queries("#{PATH}&q[status][value]=draft").size, "filtered: counted"
    assert_includes response.body, "of <b>25</b> in total"
  ensure
    AdminPortal::Blogging::PostsController.send(:remove_method, :pagination_count)
  end

  test "the definition overrides the global setting" do
    Plutonium.configuration.pagination = {count: false}
    Blogging::PostDefinition.pagination count: 20

    count_queries
    assert_includes response.body, "of <b>20+</b> in total"
  end
end

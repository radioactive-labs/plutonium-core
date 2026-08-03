# frozen_string_literal: true

require "test_helper"

# The index preloads the associations and attachments its columns will render,
# without being told which. It can, because the rendered column set is declared
# (the policy's permitted attributes) rather than discovered by running a
# template — so it is known before the collection loads.
class AdminPortal::AutoEagerLoadIndexTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup { login_as_admin(create_admin!) }

  def count_sql
    n = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      n += 1 unless /SCHEMA|TRANSACTION/.match?(payload[:name].to_s)
    end
    yield
    ActiveSupport::Notifications.unsubscribe(sub)
    n
  end

  def seed_posts(n)
    org = create_organization!
    Blogging::Post.delete_all
    n.times { create_post!(user: create_user!, organization: org) }
    org
  end

  # The property that matters isn't an absolute query count, it's that the count
  # stops tracking the row count. Measured as growth from 3 rows to 18, with
  # preloading on and off, so the comparison is against this app's own baseline
  # rather than a magic number.
  def growth_from_3_to_18
    seed_posts(3)
    get "/admin/blogging/posts"          # warm: first request pays one-time costs
    few = count_sql { get "/admin/blogging/posts" }
    assert_response :success

    seed_posts(18)
    get "/admin/blogging/posts"
    many = count_sql { get "/admin/blogging/posts" }
    assert_response :success

    many - few
  end

  test "queries do not grow with rows" do
    assert_equal 0, growth_from_3_to_18,
      "index queries must not scale with rows"
  end

  test "without preloading, queries grow one per added row" do
    Plutonium.configuration.auto_eager_load_index = false

    # At least one query per added row — the exact multiple is however many
    # association columns the page renders, which is not the point.
    assert_operator growth_from_3_to_18, :>=, 15,
      "adding 15 rows should add at least 15 queries when preloading is off"
  ensure
    Plutonium.configuration.auto_eager_load_index = true
  end

  test "opting out per controller restores the per-row queries" do
    seed_posts(18)
    on = count_sql { get "/admin/blogging/posts" }

    AdminPortal::Blogging::PostsController.class_eval do
      private def auto_eager_load_index? = false
    end
    off = count_sql { get "/admin/blogging/posts" }

    assert_operator off, :>, on,
      "with the override off, the N+1 should come back (#{off} vs #{on})"
  ensure
    AdminPortal::Blogging::PostsController.send(:remove_method, :auto_eager_load_index?)
  end

  test "the global config switches it off" do
    seed_posts(18)
    on = count_sql { get "/admin/blogging/posts" }

    Plutonium.configuration.auto_eager_load_index = false
    off = count_sql { get "/admin/blogging/posts" }

    assert_operator off, :>, on, "the global config should disable preloading"
  ensure
    Plutonium.configuration.auto_eager_load_index = true
  end

  # Attachments reflect under neither their declared name nor
  # `attachment_reflections` (empty for active_shrine), so this is the case a
  # naive `reflect_on_association` sweep silently skips.
  test "an active_shrine attachment column is preloaded too" do
    ShrineDoc.delete_all
    6.times do |i|
      io = StringIO.new("hello")
      io.singleton_class.define_method(:original_filename) { "f#{i}.txt" }
      io.singleton_class.define_method(:content_type) { "text/plain" }
      ShrineDoc.create!(title: "doc #{i}", file: io)
    end

    with_preload = count_sql { get "/admin/shrine_docs" }
    assert_response :success

    Plutonium.configuration.auto_eager_load_index = false
    without = count_sql { get "/admin/shrine_docs" }

    assert_operator with_preload, :<, without,
      "with_attached_* must be applied for a Shrine-backed attachment (#{with_preload} vs #{without})"
  ensure
    Plutonium.configuration.auto_eager_load_index = true
  end
end

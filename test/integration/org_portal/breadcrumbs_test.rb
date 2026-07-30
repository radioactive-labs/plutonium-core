# frozen_string_literal: true

require "test_helper"

# The breadcrumb trail renders every foldable segment twice — inline, and again
# as a row in the overflow menu the Stimulus controller reveals when it folds
# the inline twin away. The controller pairs the two by index, so these tests
# assert on the real rendered markup rather than a stubbed component: a drift
# between the inline `item` targets and the `menuItem` rows would silently show
# the wrong labels in the menu.
class OrgPortal::BreadcrumbsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    login_as_user(@user)
    @post = create_post!(user: @user, organization: @org)
  end

  test "edit page pairs every foldable inline segment with one menu row" do
    get edit_post_path
    assert_response :success

    assert_equal count_of('data-breadcrumbs-target="item"'),
      count_of('data-breadcrumbs-target="menuItem"'),
      "inline foldable segments and overflow menu rows must stay index-aligned"

    assert_operator count_of('data-breadcrumbs-target="item"'), :>, 0
  end

  test "edit page wires the trail up to the breadcrumbs controller" do
    get edit_post_path

    assert_includes breadcrumb_nav, 'data-controller="breadcrumbs"'
    assert_includes breadcrumb_nav, 'data-breadcrumbs-target="list"'
    assert_includes breadcrumb_nav, 'data-breadcrumbs-target="last"'
  end

  test "edit page reuses the shared dropdown for the overflow control" do
    get edit_post_path

    assert_includes breadcrumb_nav, 'data-breadcrumbs-target="overflow"'
    assert_includes breadcrumb_nav, 'data-controller="resource-drop-down"'
    assert_includes breadcrumb_nav, 'data-resource-drop-down-target="trigger"'
    assert_includes breadcrumb_nav, 'data-resource-drop-down-target="menu"'
  end

  test "the overflow control and its menu rows start hidden" do
    get edit_post_path

    overflow = breadcrumb_nav[/<li class="([^"]*)" data-breadcrumbs-target="overflow"/, 1]
    assert_includes overflow, "hidden"

    breadcrumb_nav.scan(/<li class="([^"]*)" data-breadcrumbs-target="menuItem"/).flatten.each do |classes|
      assert_includes classes, "hidden"
    end
  end

  test "a folded segment keeps the same link target as its inline twin" do
    get edit_post_path

    index_url = "/org/#{@org.to_param}/blogging/posts"
    # Once inline, once as a menu row.
    assert_equal 2, breadcrumb_nav.scan(%r{href="#{Regexp.escape(index_url)}"}).size
  end

  test "the last segment is measurable but able to ellipsize" do
    get edit_post_path

    last = breadcrumb_nav[/<li class="([^"]*)" data-breadcrumbs-target="last"/, 1]
    assert_includes last, "shrink-0"
    assert_includes last, "min-w-0"
    refute_includes last, "hidden"
  end

  test "show page has nothing foldable so renders no overflow control" do
    get post_path
    assert_response :success

    assert_includes breadcrumb_nav, 'data-breadcrumbs-target="last"'
    refute_includes breadcrumb_nav, 'data-breadcrumbs-target="overflow"'
    refute_includes breadcrumb_nav, 'data-breadcrumbs-target="item"'
  end

  # Catalog::ProductDetail is registered plural in org_portal, but nests under
  # Catalog::Product as a has_one, so its nested route is singular. The trail has
  # to read that from the *nested* route config — the top-level registration
  # can't see it.
  test "a plural show page ends at the index — the record is left to the page title" do
    assert_equal ["Dashboard", "Products"], breadcrumb_labels_for(product_path)
  end

  test "a nested has_one show page ends at the parent, mirroring the plural case" do
    # No trailing "Product detail": the heading already names it.
    assert_equal ["Dashboard", "Products", product.to_label],
      breadcrumb_labels_for("#{product_path}/nested_product_detail")
  end

  test "a nested has_one edit page names the resource and links to its show page" do
    path = "#{product_path}/nested_product_detail/edit"

    assert_equal ["Dashboard", "Products", product.to_label, "Product detail"],
      breadcrumb_labels_for(path)
    assert_includes breadcrumb_nav, %(href="#{product_path}/nested_product_detail")
  end

  test "a nested has_many show page still ends at the nested index" do
    review = create_review!(product: product, user: @user)

    assert_equal ["Dashboard", "Products", product.to_label, "Reviews"],
      breadcrumb_labels_for("#{product_path}/nested_reviews/#{review.to_param}")
  end

  # A top-level singular resource has no index to link back to, so whenever it
  # cannot offer a *link* — `show` (you are already there) and `new` (nothing to
  # link to yet) — there is nothing left to say. The old non-link span naming the
  # resource was dead weight next to a heading that already says the same thing.
  test "a top-level singular show page adds no segment of its own" do
    user_profile

    assert_equal ["Dashboard"], breadcrumb_labels_for("/org/#{@org.to_param}/user_profile")
  end

  test "a top-level singular new page adds no segment either" do
    assert_equal ["Dashboard"], breadcrumb_labels_for("/org/#{@org.to_param}/user_profile/new")
  end

  test "a top-level singular edit page names the resource" do
    user_profile

    assert_equal ["Dashboard", "User profile"],
      breadcrumb_labels_for("/org/#{@org.to_param}/user_profile/edit")
  end

  private

  def user_profile
    @user_profile ||= UserProfile.create!(user: @user, bio: "About me")
  end

  def product
    @product ||= create_product!(
      user: @user,
      organization: @org,
      category: create_category!
    ).tap { |p| create_product_detail!(product: p) }
  end

  def product_path
    "/org/#{@org.to_param}/catalog/products/#{product.to_param}"
  end

  # Only the inline <li>s — every foldable segment is also rendered as a hidden
  # row inside the overflow <li>, which would double each label.
  def breadcrumb_labels_for(path)
    get path
    assert_response :success

    Nokogiri::HTML(breadcrumb_nav)
      .css(%(nav > ol > li:not([data-breadcrumbs-target="overflow"])))
      .filter_map { |li| li.text.squish.presence }
  end

  def post_path
    "/org/#{@org.to_param}/blogging/posts/#{@post.to_param}"
  end

  def edit_post_path
    "#{post_path}/edit"
  end

  def breadcrumb_nav
    response.body[/<nav[^>]*aria-label="Breadcrumb".*?<\/nav>/m] ||
      flunk("no breadcrumb nav in the response")
  end

  def count_of(needle)
    breadcrumb_nav.scan(needle).size
  end
end

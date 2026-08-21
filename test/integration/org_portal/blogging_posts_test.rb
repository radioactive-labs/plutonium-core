# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class OrgPortal::BloggingPostsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Blogging::Post, portal: :org

  setup do
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    login_as(@user, portal: :user)
  end

  # Override to inject org id into the path prefix (org portal is tenant-scoped)
  def current_path_prefix
    "/org/#{@org.to_param}"
  end

  def create_resource!
    create_post!(user: @user, organization: @org)
  end

  def valid_create_params
    {title: "New Post", body: "New body", status: :draft,
     user: @user.to_sgid.to_s, organization: @org.to_sgid.to_s}
  end

  def valid_update_params
    {title: "Updated Title"}
  end

  # STI subtypes
  test "lists articles (STI subtype)" do
    create_article!(user: @user, organization: @org)
    get "#{current_path_prefix}/blogging/articles"
    assert_response :success
  end

  test "shows an article (STI subtype)" do
    article = create_article!(user: @user, organization: @org)
    get "#{current_path_prefix}/blogging/articles/#{article.id}"
    assert_response :success
  end

  test "lists tutorials (STI subtype)" do
    create_tutorial!(user: @user, organization: @org)
    get "#{current_path_prefix}/blogging/tutorials"
    assert_response :success
  end

  test "shows a tutorial (STI subtype)" do
    tutorial = create_tutorial!(user: @user, organization: @org)
    get "#{current_path_prefix}/blogging/tutorials/#{tutorial.id}"
    assert_response :success
  end

  # Nested resources
  test "lists comments on a post (polymorphic)" do
    post_record = create_post!(user: @user, organization: @org)
    create_comment!(commentable: post_record)
    get "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_comments"
    assert_response :success
  end

  # Creation through a polymorphic nesting, resolved by inverse_of. Rails
  # detects the inverse automatically when `as:` and the child's belongs_to
  # share a name, so this never reaches the foreign-key scan below it — worth
  # saying, because it passes with or without that branch working.
  test "creates a comment on a post through the polymorphic nested route" do
    post_record = create_post!(user: @user, organization: @org)

    assert_difference -> { Comment.count }, 1 do
      post "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_comments",
        params: {comment: {body: "Created through the nesting", user: @user.to_sgid.to_s}}
    end

    comment = Comment.order(:id).last
    assert_equal "Created through the nesting", comment.body
    # Both halves of the polymorphic reference, not just the id.
    assert_equal post_record.id, comment.commentable_id
    assert_equal post_record.class.polymorphic_name, comment.commentable_type
  end

  # The same creation where automatic inverse detection is off, so the parent
  # field can only come from the foreign-key scan. A polymorphic belongs_to
  # cannot be asked for its class — that raises — so it has to be matched on the
  # type column instead, which is what `as:` names on the parent side.
  test "creates through a polymorphic nesting that has no inverse_of" do
    post_record = create_post!(user: @user, organization: @org)

    assert_difference -> { Comment.count }, 1 do
      post "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_noninverse_comments",
        params: {comment: {body: "No inverse to lean on", user: @user.to_sgid.to_s}}
    end

    comment = Comment.order(:id).last
    assert_equal post_record.id, comment.commentable_id
    assert_equal post_record.class.polymorphic_name, comment.commentable_type
  end

  # Creating through an association that carries a scope. The list side merges
  # the relation into `parent.flagged_comments`, so a record built without the
  # scope's attributes is filtered out of the very list it was created from:
  # the create reports success and the row never appears.
  test "creates through a scoped nesting with the scope's attributes applied" do
    post_record = create_post!(user: @user, organization: @org)
    body = "Created through the scoped nesting"

    assert_difference -> { Comment.count }, 1 do
      post "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_flagged_comments",
        params: {comment: {body: body, user: @user.to_sgid.to_s}}
    end

    comment = Comment.order(:id).last
    assert comment.flagged, "expected the association's scope to supply flagged: true"

    # The symptom a user actually sees: it has to come back in that list.
    get "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_flagged_comments"
    assert_response :success
    assert_match body, response.body
  end

  # The form for a scoped nesting is built from the same association, so the
  # scope's attributes are already applied before anything is typed.
  test "renders a new form through a scoped nesting" do
    post_record = create_post!(user: @user, organization: @org)

    get "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_flagged_comments/new"
    assert_response :success
  end

  # "comment_series" singularizes to itself, so Rails suffixes the collection
  # route with _index. The nested URL builder has to match that, as the
  # top-level one already does, or every link it builds for the collection
  # names a helper that was never generated.
  test "renders a nesting whose name singularizes to itself" do
    post_record = create_post!(user: @user, organization: @org)

    get "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_comment_series"
    assert_response :success

    get "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_comment_series/new"
    assert_response :success
  end

  test "shows post detail (has_one)" do
    post_record = create_post!(user: @user, organization: @org)
    create_post_detail!(post: post_record)
    get "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_post_detail"
    assert_response :success
  end

  # The singular counterpart of the nested create above: a has_one is built with
  # `build_post_detail` rather than on a collection, so it takes the other branch.
  test "creates through a has_one nesting" do
    post_record = create_post!(user: @user, organization: @org)

    assert_difference -> { Blogging::PostDetail.count }, 1 do
      post "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_post_detail",
        params: {blogging_post_detail: {seo_title: "Built through the has_one"}}
    end

    detail = Blogging::PostDetail.order(:id).last
    assert_equal post_record.id, detail.post_id
  end

  test "lists post tags (has_many through)" do
    post_record = create_post!(user: @user, organization: @org)
    tag = create_tag!
    create_post_tag!(post: post_record, tag: tag)
    get "#{current_path_prefix}/blogging/posts/#{post_record.id}/nested_post_tags"
    assert_response :success
  end

  # Tags
  test "lists tags" do
    create_tag!
    get "#{current_path_prefix}/blogging/tags"
    assert_response :success
  end

  # Tenant scoping
  test "scoping: only shows posts from current organization" do
    my_post = create_post!(user: @user, organization: @org)
    other_org = create_organization!
    other_post = create_post!(organization: other_org)

    get "#{current_path_prefix}/blogging/posts"
    assert_response :success
    assert_match my_post.title, response.body
    refute_match other_post.title, response.body
  end

  # CSV export must never leak rows outside the current tenant — both the
  # default (filtered) export and the ?all=1 export resolve through
  # current_authorized_scope, which carries the entity scope.
  test "scoping: csv export only includes posts from the current organization" do
    require "csv"
    mine = create_post!(user: @user, organization: @org, title: "Mine #{SecureRandom.hex(4)}")
    other_org = create_organization!
    theirs = create_post!(organization: other_org, title: "Theirs #{SecureRandom.hex(4)}")

    get "#{current_path_prefix}/blogging/posts/export_csv"
    assert_response :success
    titles = CSV.parse(response.body)[1..].map { |row| row[1] }
    assert_includes titles, mine.title
    refute_includes titles, theirs.title
  end

  test "scoping: ?all=1 csv export is still confined to the current organization" do
    require "csv"
    mine = create_post!(user: @user, organization: @org, title: "Mine #{SecureRandom.hex(4)}")
    other_org = create_organization!
    theirs = create_post!(organization: other_org, title: "Theirs #{SecureRandom.hex(4)}")

    get "#{current_path_prefix}/blogging/posts/export_csv?all=1"
    assert_response :success
    titles = CSV.parse(response.body)[1..].map { |row| row[1] }
    assert_includes titles, mine.title
    refute_includes titles, theirs.title
  end
end

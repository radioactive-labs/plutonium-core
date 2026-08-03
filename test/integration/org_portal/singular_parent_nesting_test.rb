# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Nesting under a resource registered `singular: true`. The parent segment carries
# no :id, so the parent is whichever record the viewer's authorized scope resolves
# to — which only works because the scope resolves to exactly one (see
# OrgPortal::UserPolicy / LocusPortal::UserPolicy). When it doesn't, the framework
# says so rather than nesting under an arbitrary row: Plutonium::SingularScopeError.
class OrgPortal::SingularParentNestingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    # A second member, so the parent scope would resolve to many if it weren't narrowed.
    create_membership!(organization: @org, user: create_user!)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  test "a has_many nested under a singular parent resolves that parent" do
    mine = Comment.create!(body: "Mine", user: @user, commentable: create_post!(user: @user, organization: @org))
    theirs = Comment.create!(body: "Theirs", user: User.where.not(id: @user.id).first,
      commentable: create_post!(user: @user, organization: @org))

    get "#{prefix}/user/nested_comments"

    assert_response :success
    assert_includes response.body, mine.body
    refute_includes response.body, theirs.body,
      "the listing must be scoped to the resolved singular parent, not every user's"
  end

  test "a has_one nested under a singular parent resolves that parent" do
    get "#{prefix}/user/nested_user_profile/new"
    assert_response :success
  end

  test "the unscoped portal resolves a singular parent the same way" do
    get "/locus/user/nested_authored_posts"
    assert_response :success
  end

  # The failure mode the narrowing exists to prevent is covered as a unit test
  # (test/plutonium/resource/controller_test.rb) — by design no route in the
  # dummy app nests under an un-narrowed singular parent any more, which is the
  # whole point of the two policies above.
end

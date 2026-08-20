# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Where a dispatching interaction sends the user, resolved by a LIVE controller
# in a `:path` entity-scoped portal.
#
# The unit suite mocks the controller, and a mock cannot answer the only
# question that matters here: whether the URL carries the tenant. OrgPortal
# scopes to Organization with `strategy: :path`, so every resource route helper
# is entity-prefixed and takes the tenant as its first argument
# (`organization_scoped_blogging_posts_path(org, post)`). Handing the bare
# record to Response::Redirect would put it through a plain `url_for`, which
# derives the helper from the record's own route_key and knows nothing about
# that prefix — so it raises, for the common entity-scoped case.
class OrgPortal::DispatchRedirectTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  # Only #dispatch_redirect_target is under test, so this declares no subject
  # and never reaches the rest of dispatch.
  class RedirectProbeInteraction < Plutonium::Resource::Interaction
    async TestReportRun
  end

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @post = create_post!(user: @user, organization: @org)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  # The record stands in for the run, which Task 6 registers as a resource. The
  # method under test takes whatever it is given, so the tenant prefix — the
  # part `url_for` cannot produce — is pinned today against a real route.
  test "the default redirect target is an entity-prefixed URL built by resource_url_for" do
    get "#{prefix}/blogging/posts"
    assert_response :success

    interaction = RedirectProbeInteraction.new(view_context: @controller.view_context)
    target = interaction.send(:dispatch_redirect_target, @post)

    assert_equal "#{prefix}/blogging/posts/#{@post.to_param}", target
    assert_kind_of String, target,
      "a resolved URL, not the record — Response::Redirect would url_for the record"
  end

  test "a same-origin return_to wins over the run's own page" do
    get "#{prefix}/blogging/posts", params: {return_to: "#{prefix}/blogging/posts?view=table"}
    assert_response :success

    interaction = RedirectProbeInteraction.new(view_context: @controller.view_context)

    # Dispatching is not a destination: the index the user was working already
    # surfaces its in-progress runs in a banner, so sending them back costs
    # nothing and keeps their place.
    assert_equal "#{prefix}/blogging/posts?view=table",
      interaction.send(:dispatch_redirect_target, @post)
  end

  test "a return_to pointing off-origin is refused, not followed" do
    get "#{prefix}/blogging/posts", params: {return_to: "https://evil.test/steal"}
    assert_response :success

    interaction = RedirectProbeInteraction.new(view_context: @controller.view_context)

    # url_from answers nil for anything not same-origin. Without it, every bulk
    # action link is an open redirect anyone can mint.
    assert_equal "#{prefix}/blogging/posts/#{@post.to_param}",
      interaction.send(:dispatch_redirect_target, @post)
  end

  # The mirror image, and the reason the default cannot simply pass the record:
  # the helper `url_for(record)` would reach for does not exist in this portal.
  test "a plain url_for on the record cannot build that URL" do
    get "#{prefix}/blogging/posts"
    assert_response :success

    error = assert_raises(NoMethodError) { @controller.view_context.url_for(@post) }

    # It reached for the UNPREFIXED helper — derived from the record's route_key,
    # with no way to know the portal scopes by path.
    assert_match(/undefined method 'blogging_post_path'/, error.message)
  end
end
